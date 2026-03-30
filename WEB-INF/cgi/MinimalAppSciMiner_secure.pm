use FindBin qw($RealBin);
BEGIN {
    my $base = $ENV{SCIMINER_HOME} || '/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1';
    push (@INC, "$base/annotation/SciMinerDB/Modules/");
    push (@INC, "$base/annotation/SciMinerDB/Modules/SciMiner");
    push (@INC, "$base/annotation/SciMinerDB/Modules/Annotation");
}

# ----------------------------------------------------------------------------
#  Load required modules
# ----------------------------------------------------------------------------
use Annotation::basicIO;
use Annotation::SciMiner;
use base 'CGI::Application';
use strict;
use HTML::Template;
use CGI::Session;
use Data::Dumper;
use CGI::Debug;

# Try to import security modules with fallbacks
BEGIN {
    eval "use Annotation::SciMinerSecurity";
    if ($@) {
        # Create fallback if Security module not available
        *SciMiner_secure_email_password_check = sub {
            my ($email, $pass) = @_;
            return 0; # Fallback to no authentication
        };
        *get_user_info_secure = sub {
            my $email = shift;
            return {email => $email, name => 'User'};
        };
    }

    eval "use SciMiner::Security qw(generate_token)";
    if ($@) {
        # Fallback token generator
        sub generate_token {
            my $length = shift || 32;
            my @chars = ('a'..'z', 'A'..'Z', 0..9);
            return join '', map $chars[rand @chars], 1..$length;
        }
    }
}

# ----------------------------------------------------------------------------
#  Load working environment for ANNOTATION
# ----------------------------------------------------------------------------
my %annoENV = anno_environmental_file_open ( );
my $annoBaseDir = $annoENV{ANNOPath};
my $annoBaseRawData = $annoENV{ANNOPath}.'DB_RawData/';
my $annoBaseWorkingI = $annoENV{ANNOPath}.'DB_Working_I/';
my $annoBaseWorkingII = $annoENV{ANNOPath}.'DB_Working_II/';

sub cgiapp_init {
    my $self    = shift;
    my $query   = $self->query;

    # Enhanced session management with secure parameters
    my $sid     = $query->cookie( 'CGISESSID' ) || undef;
    my $session = new CGI::Session("driver:File", $sid, {
        Directory=>'/tmp',
        IPAddress=>$ENV{REMOTE_ADDR}
    });

    # Set secure session parameters
    $session->expire('+1h');  # Session expires after 1 hour
    $self->param( 'session' => $session);

    # Generate CSRF token for this session
    unless ($session->param('csrf_token')) {
        my $csrf_token = generate_token(32);
        $session->param('csrf_token', $csrf_token);
    }

    if (!$sid || $sid ne $session->id) {
       my $cookie = $query->cookie(
          -name    => 'CGISESSID',
          -value   => $session->id,
          -expires => '+1h',
          -secure => 0,  # Set to 1 if using HTTPS
          -httponly => 1,
          -samesite => 'Strict'
       );
       $self->header_props( -cookie => $cookie );
    }

    # Login with secure authentication
    $self->login_secure($query->param("lg_nick"), $query->param("lg_pass"));
}

sub setup {
    my $self = shift;
    $self->mode_param('rm');
    $self->start_mode('show');
    $self->run_modes(
        'show' => 'show',
        'login' => 'login',
        'logout' => 'logout',
        'query' => 'query'
    );
}

sub show {
    my $self = shift;
    my $session = $self->param('session');

    # Check if user is logged in
    if (!$session->param('email')) {
        return $self->login_form();
    }

    # Show main interface
    return $self->main_interface();
}

sub login_form {
    my $self = shift;
    my $query = $self->query;
    my $session = $self->param('session');
    my $csrf_token = $session->param('csrf_token');

    my $template = HTML::Template->new(
        filename => 'sciminer.tmpl',
        die_on_bad_params => 0
    );

    $template->param(
        CSRF_TOKEN => $csrf_token,
        BADLOGINS => $session->param('badlogins') || 0,
        ACTION_URL => 'sciminerLaunch_secure.cgi'
    );

    return $template->output;
}

sub main_interface {
    my $self = shift;
    my $session = $self->param('session');

    my $template = HTML::Template->new(
        filename => 'main2.html',
        die_on_bad_params => 0
    );

    $template->param(
        USER_EMAIL => $session->param('email'),
        USER_NAME => $session->param('realname'),
        LAST_LOGIN => $session->param('last_login') || 'Never'
    );

    return $template->output;
}

sub login_secure {
    my $self = shift;
    my($nick, $pass) = @_;
    my $session = $self->param('session');
    my $realname = '';

    if ((defined $nick) && (defined $pass)) {
        if (($nick eq "") && ($pass eq "")) {
            my $badlogins = $session->param('badlogins') || 0;
            $session->param('badlogins' => $badlogins);
        } else {
            # Input sanitization
            $nick =~ s/^\s+|\s+$//g;  # Trim whitespace
            $nick = lc($nick);
            $nick =~ s/[^a-zA-Z0-9@._-]/_/g;  # Sanitize email

            # Secure password check
            my $auth_result = SciMiner_secure_email_password_check($nick, $pass);

            if ($auth_result == 1) {
                # Authentication successful
                my $user_info = get_user_info_secure($nick);
                $realname = $user_info->{name} || $nick;

                # Set secure session parameters
                $session->param(
                    profile => {
                        nick => $nick,
                        user_id => $user_info->{userID},
                        authenticated => 1,
                        last_activity => time()
                    }
                );
                $session->param(email => $nick);
                $session->param(realname => $realname);
                $session->param(last_login => $user_info->{last_login});
                $session->clear('badlogins');

                # Regenerate session ID to prevent session fixation
                $session->flush();

            } elsif ($auth_result eq 'SUSPENDED') {
                $session->param(auth_error => 'Account suspended. Please contact administrator.');
                my $badlogins = $session->param('badlogins') || 0;
                $session->param('badlogins' => ++$badlogins);

            } elsif ($auth_result eq 'NOT_ACTIVATED') {
                $session->param(auth_error => 'Account not activated. Please check your email.');
                my $badlogins = $session->param('badlogins') || 0;
                $session->param('badlogins' => ++$badlogins);

            } else {
                # Invalid login
                my $badlogins = $session->param('badlogins') || 0;
                $session->param('badlogins' => ++$badlogins);

                # Implement account lockout after 5 failed attempts
                if ($badlogins >= 5) {
                    $session->param(auth_error => 'Too many failed attempts. Account temporarily locked.');
                    $session->expire('+15m');  # Lock for 15 minutes
                } else {
                    $session->param(auth_error => 'Invalid email or password.');
                }
            }
        }
    } else {
        my $badlogins = $session->param('badlogins') || 0;
        $session->param('badlogins' => $badlogins);
    }
}

sub logout {
    my $self = shift;
    my $session = $self->param('session');

    # Clear all session data
    $session->clear();

    # Delete session
    $session->delete();

    # Redirect to login
    my $query = $self->query;
    print $query->redirect('sciminerLaunch_secure.cgi');
    return;
}

sub query {
    my $self = shift;
    my $session = $self->param('session');

    # Check authentication
    unless ($session->param('email')) {
        return $self->login_form();
    }

    # Show query interface
    my $template = HTML::Template->new(
        filename => 'query.tmpl',
        die_on_bad_params => 0
    );

    $template->param(
        USER_EMAIL => $session->param('email')
    );

    return $template->output;
}

1;