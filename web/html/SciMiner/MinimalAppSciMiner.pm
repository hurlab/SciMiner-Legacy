use FindBin qw($RealBin);
BEGIN {
    my $base = $ENV{SCIMINER_HOME} || '/home/sciminer/legacy';
    push (@INC, "$base/annotation/SciMinerDB/Modules/");
}

# ----------------------------------------------------------------------------
#  Load required modules
# ----------------------------------------------------------------------------
package MinimalAppSciMiner;

use Annotation::basicIO;            
use Annotation::SciMiner;   
use base 'CGI::Application';
use strict;
use HTML::Template;
use CGI::Session;
use Data::Dumper;
use CGI::Debug;


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
    # get the current session id from the cookie
    my $sid     = $query->cookie( 'CGISESSID' ) || undef;
    my $session = new CGI::Session("driver:File", $sid, {Directory=>'/tmp'});
    $self->param( 'session' => $session);
    if (!$sid or $sid ne $session->id ) {
       my $cookie = $query->cookie(
          -name    => 'CGISESSID',
          -value   => $session->id,
          -expires => '+1h'
       );
       $self->header_props( -cookie => $cookie );
    }
    $self->login(scalar $query->param("lg_nick"), scalar $query->param("lg_pass"));
}

sub login{
    my $self 			= shift;
    my($nick, $pass) 	= @_;
    my $session 		= $self->param('session');
    my $realname 		= '';
    if ((defined $nick) && (defined $pass))# && ($nick =~ /\S/) && ($pass =~ /\S/)) 
    {   if (($nick eq "") && ($pass eq ""))
		{	my $badlogins = $session->param('badlogins') || 0;
        	$session->param('badlogins' => $badlogins);
		}else
		{   $nick =~ s/ //g;
			$nick = lc($nick);
			my $passCheckResult = SciMiner_email_password_check ($nick, $pass);
			if (!$passCheckResult)
			{	my $badlogins = $session->param('badlogins') || 0;
		    	$session->param('badlogins' => ++$badlogins);
			}else
			{   $realname	= get_realname_by_email($nick);
				# replace this check above with something real ie lookup from a database
			    $session->param(profile => {nick => $nick});
			    $session->param(email => $nick);
			    $session->param(realname => $realname);
			    $session->clear('badlogins');
			}
		}
    }else
    {	my $badlogins = $session->param('badlogins') || 0;
        $session->param('badlogins' => $badlogins);
    }
}

sub setup {
    my $self = shift;
    $self->start_mode('index');
    $self->run_modes(
        'index' 	=> 'index',
        'logout' 	=> 'logout'
    );
    $self->tmpl_path($FindBin::RealBin . "/");
}

sub logout{
    my $self = shift;
    my $session = $self->param('session');
    $session->clear('profile');
    return $self->index();
}

sub processtmpl{
# processes the template with parameters gathered from the application object
    my ($self,$tmplname) = @_;
    my $query = $self->query();
    my $template = $self->load_tmpl($tmplname, loop_context_vars => 1,);
    #my $tmplpar = $self->param('tmplpar') || {};
    $template->param(PROFILE => $self->param('session')->param("profile"));
    $template->param(BADLOGINS => $self->param('session')->param("badlogins"));
    $template->param(MYURL => $query->url());
    $template->param(EMAIL => $self->param('session')->param("email"));
    $template->param(REALNAME => $self->param('session')->param("realname"));
    my $html = $template->output;
    return $html;
}

sub index{
    my $self = shift;
    return $self->processtmpl('sciminerIndex.tmpl') ;
}



1;    # Perl requires this at the end of all modules
