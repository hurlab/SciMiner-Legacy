#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                createSciMinerAccount_secure.cgi for SciMiner on the web
#                 Enhanced with security improvements (bcrypt, CSRF, validation)
#
#******************************************************************************
BEGIN {
push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/");
push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/SciMiner");
}

# ----------------------------------------------------------------------------
#  Load required modules
# ----------------------------------------------------------------------------
use Annotation::basicIO;
use Annotation::SciMiner;
use CGI qw(:standard);
use CGI::Debug;
use CGI::Session;
use Digest::SHA qw(sha256_hex);
use SciMiner::Security qw(hash_password verify_password generate_token);
use strict;

# Enable UTF-8 for better security
binmode STDOUT, ':utf8';

# Security headers
print header(
    -type => 'text/html',
    -charset => 'UTF-8',
    -Cache_Control => 'no-cache, no-store, must-revalidate',
    -Pragma => 'no-cache',
    -Expires => '0'
);

#here's a stylesheet incorporated directly into the page
my  $newStyle=<<END;
<!--
body {
    margin-left: 10px;
    font-family: Arial, sans-serif;
}
-->
END

# ----------------------------------------------------------------------------
#  Load working environment for ANNOTATION
# ----------------------------------------------------------------------------
my %annoENV = anno_environmental_file_open ();
my $annoBaseDir = $annoENV{ANNOPath};

# Initialize session for CSRF protection
my $session = CGI::Session->new("driver:File", undef, {Directory=>'/tmp'});
my $csrf_token = generate_token(32);
$session->param('csrf_token', $csrf_token);

# Generate and store CSRF token for form
if (!param('submit')) {
    # Display the form with CSRF token
    display_form($csrf_token);
    exit;
}

# Verify CSRF token on form submission
my $form_token = param('csrf_token') || '';
my $session_token = $session->param('csrf_token') || '';

unless ($form_token && $form_token eq $session_token) {
    display_error("Security validation failed. Please try again.");
    exit;
}

# Input validation and sanitization
my $email = validate_email(param('lg_nick') || '');
my $password = param('lg_pass') || '';
my $confirm_password = param('lg_pass2') || '';
my $name = validate_string(param('name') || '');
my $instName = validate_string(param('instName') || '');
my $instDeptName = validate_string(param('instDeptName') || '');
my $instAddress = validate_string(param('instAddress') || '');
my $instCity = validate_string(param('instCity') || '');
my $instState = validate_string(param('instState') || '');
my $instZipCode = validate_string(param('instZipCode') || '');
my $instCountry = validate_string(param('instCountry') || '');

# Validation checks
unless ($email && $password && $name) {
    display_error("Required fields: Email, Password, and Name");
    exit;
}

# Email validation
unless ($email =~ /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/) {
    display_error("Invalid email format");
    exit;
}

# Password strength validation
unless (length($password) >= 8) {
    display_error("Password must be at least 8 characters long");
    exit;
}

unless ($password eq $confirm_password) {
    display_error("Passwords do not match");
    exit;
}

# Check for weak password patterns
if ($password =~ /^(123456|password|qwerty|abc123)/i) {
    display_error("Password is too common. Please choose a stronger password");
    exit;
}

# Check if email already exists
if (email_exists($email)) {
    display_error("An account with this email already exists");
    exit;
}

# Hash the password
my $password_hash = hash_password($password);

# Create user account
my $insertionStatus = create_user(
    $email, $name, $password_hash,
    $instName, $instDeptName, $instAddress,
    $instCity, $instState, $instZipCode, $instCountry
);

if ($insertionStatus) {
    display_success($email);
} else {
    display_error("Failed to create account. Please try again.");
}

exit;

# Subroutines
sub validate_email {
    my ($email) = @_;
    $email = lc($email);
    $email =~ s/^\s+|\s+$//g;
    $email =~ s/[<>'"]//g;  # Remove HTML special chars
    return $email;
}

sub validate_string {
    my ($str) = @_;
    $str =~ s/^\s+|\s+$//g;
    $str =~ s/[<>'"]//g;
    $str =~ s/[;&|`$()]//g;  # Remove command injection chars
    return $str;
}

sub email_exists {
    my ($email) = @_;

    my $username = $annoENV{username} || return 0;
    my $password = $annoENV{password} || return 0;
    my $SciMinerDB = $annoENV{SciMinerDB} || return 0;

    my $dbh = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || return 0;

    my $sth = $dbh->prepare("SELECT COUNT(*) FROM user WHERE email = ?");
    $sth->execute($email);
    my ($count) = $sth->fetchrow_array;
    $sth->finish();
    $dbh->disconnect();

    return $count > 0;
}

sub create_user {
    my ($email, $name, $password_hash, $instName, $instDeptName, $instAddress,
        $instCity, $instState, $instZipCode, $instCountry) = @_;

    my $username = $annoENV{username} || return 0;
    my $password = $annoENV{password} || return 0;
    my $SciMinerDB = $annoENV{SciMinerDB} || return 0;
    my $MaxDoc = $annoENV{MaxDoc} || 1000;
    my $MaxNewDoc = $annoENV{MaxNewDoc} || 100;

    my $dbh = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || return 0;

    # Use prepared statement to prevent SQL injection
    my $sth = $dbh->prepare(qq{
        INSERT INTO user (
            email, name, password_hash, password,
            maxDoc, maxNewDoc, editLevel,
            institute, deptOrLab, instAddress, instCity, instState,
            instZipCode, instCountry, signUpDate, signUpTime,
            email_verified, email_verification_token
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, curdate(), curtime(), ?, ?)
    });

    # Generate verification token
    my $verification_token = generate_token(64);

    my $result = $sth->execute(
        $email, $name, $password_hash, '',  # Keep empty password field for now
        $MaxDoc, $MaxNewDoc, 3,
        $instName, $instDeptName, $instAddress, $instCity, $instState,
        $instZipCode, $instCountry,
        TRUE, $verification_token
    );

    $sth->finish();
    $dbh->disconnect();

    return $result;
}

sub display_form {
    my ($csrf_token) = @_;

print <<END;
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Create SciMiner Account</title>
    <link rel="stylesheet" href="/SciMiner1.1/css/sciminer-modern.css">
    <style type="text/css">
    body { font-family: Arial, sans-serif; margin: 20px; }
    .form-group { margin-bottom: 15px; }
    label { display: block; margin-bottom: 5px; font-weight: bold; }
    input[type="text"], input[type="password"], input[type="email"] {
        width: 300px; padding: 8px; border: 1px solid #ccc; border-radius: 4px;
    }
    .required { color: red; }
    .error { color: red; font-weight: bold; }
    .success { color: green; font-weight: bold; }
    </style>
</head>
<body bgcolor="#EAF4F4">
<div class="pageHeader">
    <h1 align="center">Create SciMiner Account</h1>
</div>

<form method="post" action="createSciMinerAccount_secure.cgi" name="accountCreation">
    <input type="hidden" name="csrf_token" value="$csrf_token">

    <div class="form-group">
        <label for="lg_nick">Email Address <span class="required">*</span></label>
        <input type="email" id="lg_nick" name="lg_nick" required maxlength="100">
        <small>We'll never share your email with anyone else.</small>
    </div>

    <div class="form-group">
        <label for="lg_pass">Password <span class="required">*</span></label>
        <input type="password" id="lg_pass" name="lg_pass" required minlength="8">
        <small>Must be at least 8 characters long.</small>
    </div>

    <div class="form-group">
        <label for="lg_pass2">Confirm Password <span class="required">*</span></label>
        <input type="password" id="lg_pass2" name="lg_pass2" required>
    </div>

    <div class="form-group">
        <label for="name">Full Name <span class="required">*</span></label>
        <input type="text" id="name" name="name" required maxlength="100">
    </div>

    <div class="form-group">
        <label for="instName">Institution Name</label>
        <input type="text" id="instName" name="instName" maxlength="200">
    </div>

    <div class="form-group">
        <label for="instDeptName">Department or Laboratory</label>
        <input type="text" id="instDeptName" name="instDeptName" maxlength="200">
    </div>

    <div class="form-group">
        <label for="instAddress">Address</label>
        <input type="text" id="instAddress" name="instAddress" maxlength="500">
    </div>

    <div class="form-group">
        <label for="instCity">City</label>
        <input type="text" id="instCity" name="instCity" maxlength="100">
    </div>

    <div class="form-group">
        <label for="instState">State/Province</label>
        <input type="text" id="instState" name="instState" maxlength="100">
    </div>

    <div class="form-group">
        <label for="instZipCode">Zip/Postal Code</label>
        <input type="text" id="instZipCode" name="instZipCode" maxlength="20">
    </div>

    <div class="form-group">
        <label for="instCountry">Country</label>
        <input type="text" id="instCountry" name="instCountry" maxlength="100">
    </div>

    <div style="margin-top: 20px;">
        <input type="submit" name="submit" value="Create Account">
        <input type="reset" value="Clear Form">
    </div>
</form>

<hr>
<p align="center">
    <a href="sciminerLaunch.cgi">Back to Login</a>
</p>

</body>
</html>
END
}

sub display_error {
    my ($message) = @_;

print <<END;
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Account Creation Error</title>
    <link rel="stylesheet" href="/SciMiner1.1/css/sciminer-modern.css">
</head>
<body bgcolor="#EAF4F4">
    <div style="text-align: center; margin-top: 50px;">
        <h2 class="error">Account Creation Failed</h2>
        <p class="error">$message</p>
        <p><a href="javascript:history.back()">← Go Back</a></p>
    </div>
</body>
</html>
END
}

sub display_success {
    my ($email) = @_;

print <<END;
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Account Created Successfully</title>
    <link rel="stylesheet" href="/SciMiner1.1/css/sciminer-modern.css">
</head>
<body bgcolor="#EAF4F4">
    <div style="text-align: center; margin-top: 50px;">
        <h2 class="success">Account Created Successfully!</h2>
        <p>Your account has been created for: <strong>$email</strong></p>
        <p>You can now <a href="sciminerLaunch.cgi">log in to SciMiner</a></p>
    </div>
</body>
</html>
END
}