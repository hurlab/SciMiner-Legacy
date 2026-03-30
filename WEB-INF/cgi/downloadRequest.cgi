#!/usr/bin/perl
# Add current directory to Perl module path
use FindBin qw($RealBin);
use lib $RealBin;

#******************************************************************************
#
#                downloadRequest.cgi for SciMiner on the web
#
#                                         Written By Junguk HUR
#                                         juhur @ umich . edu
#
#  Created	: 11/14/2008
#  Desc		: This CGI script allows users to download the SciMiner
#
#******************************************************************************
BEGIN {
push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/");
}

# ----------------------------------------------------------------------------
#  Load required modules
# ----------------------------------------------------------------------------
use Annotation::basicIO;            
use Annotation::SciMiner;            
use CGI qw(:standard);
use CGI::Debug;
use SciMinerUI qw(print_topbar print_footer print_head_extras);
#use warnings;
use strict;

#here's a stylesheet incorporated directly into the page
my  $newStyle=<<END;
<!-- 
body {
    margin-left: 10px;
}
-->
END


# here is some javascript

# ----------------------------------------------------------------------------
#  Load working environment for ANNOTATION
# ----------------------------------------------------------------------------
my %annoENV = anno_environmental_file_open ( );
my $annoBaseDir = $annoENV{ANNOPath};


#------------------------------------------------------------------------------
#  Automatically update the server's current URL for cgi-bin
#------------------------------------------------------------------------------
my $query = new CGI;
my $my_url = $query->self_url;
my @tmpSplit1 = split(/\/\//, $my_url);
my @tmpSplit2 = split(/\//, $tmpSplit1[1]);
my $tmpLocalURL = "http://$tmpSplit2[0]/";


#------------------------------------------------------------------------------
#  Initialize varialbes
#------------------------------------------------------------------------------
my $CurrentDate = `date`;


#------------------------------------------------------------------------------
#  Initialize the CGI page
#------------------------------------------------------------------------------
print header;
print $query->start_html(-title=>'SciMiner Package Download', 
                        -author=>'InformaticsTools@gmail.com',
                        -meta=>{'keywords'	=>	'Junguk Hur SciMiner text mining text-mining bioinformatics',
                                'copyright'	=>	'copytight 2006-8 Junguk Hur'},
                        -style=>{-src=>['/SciMiner1.1/css/sciminer-modern.css'], -code=>$newStyle}
                        );
print_head_extras();
print_topbar();


#print_SciMiner_Header();



#------------------------------------------------------------------------------
#  Check parameters submitted
#------------------------------------------------------------------------------
my $package				= param("package");
my @errorMessage		= ();

my $userEmail			= param("userEmail");
my $userFirstName		= param("userFirstName");
my $userLastName		= param("userLastName");
my $userInstName		= param("userInstName");
my $userInstDeptName	= param("userInstDeptName");
my $userInstAddress		= param("userInstAddress");
my $userInstCity		= param("userInstCity");
my $userInstState		= param("userInstState");
my $userInstZipCode		= param("userInstZipCode");
my $userInstCountry		= param("userInstCountry");

my $usageAgreed			= param("usageAgreed");


#------------------------------------------------------------------------------
#	Check the transferred content
#------------------------------------------------------------------------------
if (((not defined $package) 	|| ($package eq "")) && (not defined param("formSubmit")))
{	push @errorMessage, "Package is not specified.";
}elsif (defined param("formSubmit"))
{	
	if ((defined $usageAgreed) && ($usageAgreed eq 'I understand and accept the agreements above'))
	{	#  Check other parameters
		if ((defined $userEmail) 		&& ($userEmail ne "") 			&&
			(defined $userFirstName) 	&& ($userFirstName ne "") 		&&
			(defined $userLastName) 	&& ($userLastName ne "") 		&&
			(defined $userInstName) 	&& ($userInstName ne "") 		&&
			(defined $userInstDeptName) && ($userInstDeptName ne "") 	&&
			(defined $userInstAddress) 	&& ($userInstAddress ne "") 	&&
			(defined $userInstCity) 	&& ($userInstCity ne "") 		&&
			(defined $userInstState) 	&& ($userInstState ne "") 		&&
			(defined $userInstZipCode) 	&& ($userInstZipCode ne "") 	&&
			(defined $userInstCountry) 	&& ($userInstCountry ne ""))
		{	
			#  Check email format
		    if ($userEmail =~ /^[\w|\.]+\@.*\..*/)
			{   # This is a profer email address
				generate_download_page_with_link ($package, \%annoENV, $userEmail);
				print "<br><br><p class='titleBarName1' align='center'>A download link has been sent to your email address. Please check your mailbox.<br><br>Thank you for downloading SciMiner.<br><br>Your comments and suggestions will be greatly appreciated.<br><br><a href=\"mailto:$annoENV{AdminEmail}?subject=Regarding SciMiner\">$annoENV{AdminEmail}</a></p>";
				
				save_download_info_into_database ( \%annoENV, $package, $userEmail, $userFirstName, $userLastName, $userInstName, 
													$userInstDeptName, $userInstAddress, $userInstCity, $userInstState, $userInstZipCode, $userInstCountry );
				print_end_html();
				exit;
			}else
			{   push @errorMessage, "E-mail format is unacceptable.";
			}
		}else
		{	push @errorMessage, "Some of the required fields are not enterd.";
		}
	}else
	{	#  This means, user did not agreeded.
		push @errorMessage, "You have to accept the agreements to download the SciMiner standalone versions.";
	}
}else
{	# possible the initial screen
	print_agreement();
	print_your_information();
}




#------------------------------------------------------------------------------
#	Check error message and display
#------------------------------------------------------------------------------
if (defined $errorMessage[0])
{	display_errorMessage_SciMiner_CGI(\@errorMessage);
	print_agreement();
	print_your_information();	print_end_html();
	exit;
}else
{	# Create the URL
	print_end_html();
	exit;
}







#------------------------------------------------------------------------------
#	Sub-routines
#------------------------------------------------------------------------------


sub print_SciMiner_Header
{   print "<p align=\"center\" class=\"pageName\"><b><U>SciMiner Package Download</U></b></p>
           ";
}


sub print_end_html
{   print_footer();
    print end_html;
}


sub display_errorMessage_SciMiner_CGI
{   my $errorMessageRef = shift;
    
    if (not defined $errorMessageRef)
    {   return;
    }
    
    print "<font color=\"red\">";
    for (my $i=0; $i < scalar @{$errorMessageRef}; $i++)
    {   if ($$errorMessageRef[$i] ne "")
        {   print " Error ".($i+1).": $$errorMessageRef[$i]<br>";
        }
    }
    print "</font>";
}



sub print_agreement
{	print "<br><p class=\"sectionTitleName1\" align=\"center\"><b>SciMiner Standalone Version Agreements</b><\p>";
	print "<p class=\"titleBarName1\"><b>SciMiner is a freely available tool but the use of SciMiner is strictly limited to academic research purposes. SciMiner must not be used for any commercial purpose. We, the developers of the SciMiner, and the University of North Dakota are not responsible in away for any trouble that might be caused by use or alteration of the SciMiner system. It must be noted that the copyrights of the processed articles belong to their respective publishers not to the SciMiner users or developers.</b></p>";
	print "<form name=\"form1\" action=\"downloadRequest.cgi\" method=\"POST\" enctype=\"multipart/form-data\">
			<u>Check here if you understand and accept the agreements above.</u>
			<input type=\"checkbox\" name=\"usageAgreed\" value=\"I understand and accept the agreements above\"><br><br>";
}


			

sub print_your_information
{	print "<p class=\"sectionTitleName1\" align=\"center\"><b>Your Information</b><\p>";
	print "<p class=\"titleBarName1\">Fill out the following contact information and click 'Submit' button. <b>A download link</b> will be automatically sent to your email address. Please, use your <b>institutional</b> information here and <b>all fields are required</b>.</p>
	
			<table border='1'>
				<tr>
					<th width='150'>
						Institutional Email
					</th>
					<td width='300'>
						<INPUT TYPE='text' NAME='userEmail' size=\"35\">
					</td>				
				</tr>
				<tr>
					<th width='150'>
						First Name
					</th>
					<td width='300'>
						<INPUT TYPE='text' NAME='userFirstName' size=\"35\">
					</td>				
				</tr>
				<tr>
					<th width='150'>
						Last Name
					</th>
					<td width='300'>
						<INPUT TYPE='text' NAME='userLastName' size=\"35\">
					</td>				
				</tr>
				<tr>
					<th width='150'>
						Institution
					</th>
					<td width='300'>
						<INPUT TYPE='text' NAME='userInstName' size=\"35\">
					</td>				
				</tr>
				<tr>
					<th width='150'>
						Department 
					</th>
					<td width='300'>
						<INPUT TYPE='text' NAME='userInstDeptName' size=\"35\">
					</td>				
				</tr>
				<tr>
					<th width='150'>
						Address
					</th>
					<td width='300'>
						<INPUT TYPE='text' NAME='userInstAddress' size=\"35\">
					</td>				
				</tr>
				<tr>
					<th width='150'>
						City
					</th>
					<td width='300'>
						<INPUT TYPE='text' NAME='userInstCity' size=\"35\">
					</td>				
				</tr>
				<tr>
					<th width='150'>
						State
					</th>
					<td width='300'>
						<INPUT TYPE='text' NAME='userInstState' size=\"35\">
					</td>				
				</tr>
				<tr>
					<th width='150'>
						Zip code
					</th>
					<td width='300'>
						<INPUT TYPE='text' NAME='userInstZipCode' size=\"35\">
					</td>				
				</tr>
				<tr>
					<th width='150'>
						Country
					</th>
					<td width='300'>
						<INPUT TYPE='text' NAME='userInstCountry' size=\"35\">
					</td>				
				</tr>
			</table>
			
		<br>
		 <input type='submit' name=\"formSubmit\" value=\"Submit\">&nbsp;&nbsp;<INPUT TYPE=\"RESET\">
		 <input type=\"hidden\" name=\"package\" value=\"$package\">

	</form>
	<br><br>
			  ";
			
}







sub generate_download_page_with_link
{	my $package			= shift;
	my $annoENVRef		= shift;
	my $email			= shift;

	#  Check for output directory
	my $outputDirectory	= $$annoENVRef{SciMinerWebPath}.'Temp/';
	mkdir ($outputDirectory) || print "";
	
	
	#  Database Access Information
    my $SciMinerDB  = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
    my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
    my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");


    #  ------------------------------------------------------------------------
    #  Retrieve User Information from SciMinerDB
    #  ------------------------------------------------------------------------
    my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                      return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);

    my $sql         = "SELECT packageI, package2I, package2II FROM download";
    my $sth         = $dbh->prepare($sql);
    $sth->execute();
    my @row         = $sth->fetchrow_array;


	my $fileName		= int(rand(1000000000000000000)).'.txt';
	my $resultFile		= "/tmp/$fileName";
	open (TMP, ">".$resultFile);
	print TMP "Here are the links for downloading the SciMiner standalone versions\n\n";
	
	if ($package == 1)
	{	my $tmpShortFileName	= 'SciMiner_Package_I_'.(int(rand(1000000000000))).'.tar.gz';
		if (-f $outputDirectory.$tmpShortFileName)
		{	unlink ($outputDirectory.$tmpShortFileName);	
		}
		`ln -s $$annoENVRef{SciMinerWebPath}$row[0] $outputDirectory$tmpShortFileName`;
	
		print TMP "Click the link below or copy/paste into your Internet browser to download the SciMiner package I\n\n
				  ! File: $$annoENVRef{SciMinerServerURL}SciMiner/Temp/$tmpShortFileName\n\n\n
				  -- Do not reply to this email --
				  -- Any question or comment should be addressed to $$annoENVRef{AdminEmail} --\n\n";
	  
	}else
	{	my $randNumber			= int(rand(1000000000000));
		my $tmpShortFileName1	= 'SciMiner_Package_II_'.$randNumber.'.zip';
		my $tmpShortFileName2	= 'SciMiner_Package_II_'.$randNumber.'.z01';
		
		if (-f $outputDirectory.$tmpShortFileName1)
		{	unlink ($outputDirectory.$tmpShortFileName1);	
		}
		if (-f $outputDirectory.$tmpShortFileName2)
		{	unlink ($outputDirectory.$tmpShortFileName2);	
		}
				
		`ln -s $$annoENVRef{SciMinerWebPath}$row[1] $outputDirectory$tmpShortFileName1`;
		`ln -s $$annoENVRef{SciMinerWebPath}$row[2] $outputDirectory$tmpShortFileName2`;		
	
		print TMP "Click the link below or copy/paste into your Internet browser to download the SciMiner package II\n\n
			  You need to download both of the files and then unzip them.\n\n
			  ! File1: $$annoENVRef{SciMinerServerURL}SciMiner/Temp/$tmpShortFileName1\n
			  ! File2: $$annoENVRef{SciMinerServerURL}SciMiner/Temp/$tmpShortFileName2\n\n\n
			  -- Do not reply to this email --
			  -- Any question or comment should be addressed to $$annoENVRef{AdminEmail} --\n\n";
	}
	
	print TMP "\n\n";
	close TMP;
	
	`mail -s \"SciMiner -- Download link .\" \"$email\" < $resultFile`;
    unlink ($resultFile);
    
}











sub save_download_info_into_database
{	my $annoENVRef				= shift;
	my $package					= shift;
	my $userEmail				= shift;
	my $userFirstName			= shift;
	my $userLastName			= shift;
	my $userInstName			= shift;
	my $userInstDeptName		= shift;
	my $userInstAddress			= shift;
	my $userInstCity			= shift;
	my $userInstState			= shift;
	my $userInstZipCode			= shift;
	my $userInstCountry 		= shift;
													
	
	#  Database Access Information
    my $SciMinerDB  = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
    my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
    my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");


    #  ------------------------------------------------------------------------
    #  Retrieve User Information from SciMinerDB
    #  ------------------------------------------------------------------------
    my $dbh         = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0}) || 
                      return (-1, "!ERROR: Couldn't connect to database ".$DBI::errstr);

	my $columns		= 'package, userEmail, userFirstName, userLastName, userInstName, userInstDeptName, userInstAddress, userInstCity, userInstState, userInstZipCode, userInstCountry, downloadDate, downloadTime';
	
	#  Remove any ' or "
	$userFirstName			=~ s/\"|\'//g;
	$userLastName			=~ s/\"|\'//g;
	$userInstName			=~ s/\"|\'//g;
	$userInstDeptName		=~ s/\"|\'//g;
	$userInstAddress		=~ s/\"|\'//g;
	$userInstCity			=~ s/\"|\'//g;
	$userInstState			=~ s/\"|\'//g;
	$userInstZipCode		=~ s/\"|\'//g;
	$userInstCountry 		=~ s/\"|\'//g;
	
	
	#  Try to insert content
    $dbh->do("INSERT INTO `downloadhistory` ($columns) VALUES ($package, \"$userEmail\", \"$userFirstName\", \"$userLastName\", \"$userInstName\", \"$userInstDeptName\", \"$userInstAddress\", \"$userInstCity\", \"$userInstState\", \"$userInstZipCode\", \"$userInstCountry\", curdate(), curtime())") || print "INSERT INTO `downloadhistory` ($columns) VALUES ($package, \"$userEmail\", \"$userFirstName\", \"$userLastName\", \"$userInstName\", \"$userInstDeptName\", \"$userInstAddress\", \"$userInstCity\", \"$userInstState\", \"$userInstZipCode\", \"$userInstCountry\", curdate(), curtime())\n";
    
    
    
    #  Retrieve the downloadHistoryID
	my $sth			= $dbh->prepare("SELECT downloadHistoryID FROM downloadhistory ORDER BY downloadHistoryID DESC LIMIT 1");
    $sth->execute();
    my @row         = $sth->fetchrow_array;#($result);
    my $downloadHistoryID	= $row[0];
    
	#  Send an information email to the system administrator	
	my $fileName		= int(rand(1000000000000000000)).'.txt';
	my $resultFile		= "/tmp/$fileName";
	open (TMP, ">".$resultFile);
	print TMP 	"\nDear System Administrator,\n\n".
			 	"Here is the detail.\n\n".
			 	"downloadHistoryID	:	$downloadHistoryID\n".
			 	"package	:	$package\n".
			 	"userEmail	:	$userEmail\n".
			 	"userFirstName	:	$userFirstName\n".
			 	"userLastName	:	$userLastName\n".
			 	"userInstName	:	$userInstName\n".
			 	"userInstDeptName	:	$userInstDeptName\n".
			 	"userInstAddress	:	$userInstAddress\n".
			 	"userInstCity	:	$userInstCity\n".
			 	"userInstState	:	$userInstState\n".
			 	"userInstZipCode	:	$userInstZipCode\n".
			 	"userInstCountry	:	$userInstCountry\n\n\n";
	close TMP;
	
	`mail -s \"SciMiner -- A new download request has been processed.\" \"$$annoENVRef{AdminEmail}\" < $resultFile`;
    unlink ($resultFile);


}






