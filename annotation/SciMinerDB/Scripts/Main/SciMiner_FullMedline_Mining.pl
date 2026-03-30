#!/usr/bin/perl -w
# ----------------------------------------------------------------------------
#  Specify the Annotation modules location
# ----------------------------------------------------------------------------
BEGIN {push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/");}

# ----------------------------------------------------------------------------
#  Version Descriptoin
# ----------------------------------------------------------------------------
#
#            This is modified version of SciMiner v2.1 main script
#    designed for working with JUMInerDB (MySQL) and web-service
#
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
#  Load required modules
# ----------------------------------------------------------------------------
use Annotation::basicIO;            
use Annotation::SciMiner;   
use Annotation::SciMinerMining;
use DBI;
use Getopt::Long; 
use strict;
use warnings;


#  Load working environment for ANNOTATION
my %annoENV = anno_environmental_file_open ( );
my $annoBaseDir = $annoENV{ANNOPath};

#  Database Access Information
my $SciMinerDB   = "DBI:mysql:database=".$annoENV{DB} || return (-1, "!ERROR: No database specified");
my $username    = $annoENV{username} || return (-1, "!ERROR: No username specified");
my $password    = $annoENV{password} || return (-1, "!ERROR: No password specified");

    

# ------------------------------------------------------------------------------
#
#  Get User Option
#
# ------------------------------------------------------------------------------
my $hugo2externalFileName       = '';
my $engDicFileName              = '';
my $ignoreListFileName          = '';
my $excludeListFileName         = '';
my $includeListFileName         = '';
my $trimmedFinalFileName        = '';
my $uniqueSymbolFileName        = '';
my $uniqueNameFileName          = '';
my $duplicateSymbolFileName     = '';
my $duplicateNameFileName       = '';
my $programName                 = '';
my $beginPartFileName			= '';
my $middlePartFileName			= '';
my $geneRifFileName             = '';
my $dbUpdateOption				= 1;		# If 0, DB will not be updated

my $SciMinerDicDir       = "$annoENV{SciMinerPath}/Work/Dictionary";
my $SciMinerCorpusDir    = "$annoENV{SciMinerPath}/CorpusData/TmpProcessed/";
my $SciMinerTempDir      = "$annoENV{SciMinerPath}/Work/Temp/";

my $InputFileMode = '';


#  Get command line options
GetOptions ( 	"trim=s"           => \$trimmedFinalFileName,
             	"external=s"       => \$hugo2externalFileName,
				"exclude=s"        => \$excludeListFileName,
				"include=s"        => \$includeListFileName,
				"ignore=s"         => \$ignoreListFileName,
				"eng=s"            => \$engDicFileName,
				"uniqsym=s"        => \$uniqueSymbolFileName,
				"uniqname=s"       => \$uniqueNameFileName,
				"dupsym=s"         => \$duplicateSymbolFileName, 
				"dupname=s"        => \$duplicateNameFileName,
				"pname=s"          => \$programName,
				"partbegin=s"		=> \$beginPartFileName,
				"partmiddle=s"		=> \$middlePartFileName,
				"generif=s"        => \$geneRifFileName,
				"dbupdate=s"		=> \$dbUpdateOption,
				"dicdir=s"			=> \$SciMinerDicDir,
				"corpdir=s"		=> \$SciMinerCorpusDir,
				"tempdir=s"		=> \$SciMinerTempDir
            );
             

             
# ------------------------------------------------------------------------------
#
#  Load required files
#
# ------------------------------------------------------------------------------           
open (WORDLIST, "$SciMinerDicDir/$engDicFileName" ) 				|| LogQuery( "! Can't open WORDLIST list\n");
open (IGNORE, "$SciMinerDicDir/$ignoreListFileName" ) 				|| LogQuery( "! Can't open IGNORE list\n");
open (UNIQSYM, "$SciMinerDicDir/$uniqueSymbolFileName" ) 			|| LogQuery( "! Can't open UNIQSYM list\n");
open (UNIQNAME, "$SciMinerDicDir/$uniqueNameFileName" ) 			|| LogQuery( "! Can't open UNIQNAME list\n");
open (DUPSYM, "$SciMinerDicDir/$duplicateSymbolFileName" ) 			|| LogQuery( "! Can't open DUPSYM list\n");
#open (DUPNAME, "$SciMinerDicDir/$duplicateNameFileName" ) 			|| LogQuery( "! Can't open DUPNAME list\n");
open (INCLUDE, "$SciMinerDicDir/$includeListFileName" ) 			|| LogQuery( "! Can't open INCLUDE list\n");
open (EXCLUDE, "$SciMinerDicDir/$excludeListFileName" ) 			|| LogQuery( "! Can't open EXCLUDE list\n");
open (IDCONTENT, "$SciMinerDicDir/$trimmedFinalFileName" ) 			|| LogQuery( "! Can't open IDCONTENT list\n");
open (PMIDTODOCID, "$annoENV{SciMinerPath}/Work/CurrentList" ) 		|| LogQuery( "! Can't open PMIDTODOCID currentList\n");
open (PARTNAMEBEGIN, "$SciMinerDicDir/$beginPartFileName" ) 		|| LogQuery( "! Can't open PARTNAMEBEGIN list\n");
open (PARTNAMEMIDDLE, "$SciMinerDicDir/$middlePartFileName" ) 		|| LogQuery( "! Can't open PARTNAMEMIDDLE list\n");
open (GENERIF, "$SciMinerDicDir/$geneRifFileName" ) 				|| LogQuery( "! Can't open GENERIF list\n");


# ------------------------------------------------------------------------------
#  File#01, PMID2DOCID -- Conversion from pmid to local SciMiner document ID
# ------------------------------------------------------------------------------
LogQuery("! Loading pmid2docID in the CurrentList ...");
my %pmid2docID  = ();
while(<PMIDTODOCID>)
{   my $line = $_;
    $line =~ s/\r|\n//g;
    my @tmpSplit = split (/\t/, $line);
    $pmid2docID{$tmpSplit[0]} = $tmpSplit[1];
}
close (PMIDTODOCID);


# ------------------------------------------------------------------------------
#  File#02, WORDLIST and IGNORE -- Words from English dictionary (discarding name)
# ------------------------------------------------------------------------------
my %wordList 		= ();	# A hash from English dictionary words
my %ignoreWordOnly 	= ();	# A has from Ignore word only

LogQuery("! Loading dictionary words ...");
while (<WORDLIST>) 
{   my $line = lc($_);          $line =~ s/\r|\n//g;
    if (not defined $wordList{$line})		{   $wordList{$line} = 1;	}
}   close WORDLIST;

LogQuery("! Loading words to be ignored ...");
while (<IGNORE>) 
{   my $line = lc($_);          $line =~ s/\r|\n//g;
    if (not defined $wordList{$line})		{	$wordList{$line} = 1;	}
    if (not defined $ignoreWordOnly{$line})	{   $ignoreWordOnly{$line} = 1;	}
    if ($line =~ /\-/)
    {	$line =~ s/\-/ /g;
    	if (not defined $wordList{$line})		{	$wordList{$line} = 1;	}
    	if (not defined $ignoreWordOnly{$line})	{   $ignoreWordOnly{$line} = 1;	}
    }
}   close IGNORE;


# ------------------------------------------------------------------------------
#  File#04, INCLUDE 	-- Symbols to be included (case insensitive)
# ------------------------------------------------------------------------------
LogQuery("! Loading \'INCLUDE\' words ...");
my %INCLUDESYMBOLMODE	= ();	# Condition check or not (1=check)
my %INCLUDESYMBOLCOND	= ();	# Conditions to be checked against	
while (<INCLUDE>)
{   my $line 		= lc($_);
	$line 			=~ s/\r|\n//g;
    my @tmpSplit 	= split (/\t/, $line);
    my $tmpKey 		= $tmpSplit[0];
    if (defined $tmpSplit[1]) 
    {   $INCLUDESYMBOLMODE{$tmpKey} = 1;               # 1 for conditional/ 0 for nonconditional
        shift(@tmpSplit);
        $INCLUDESYMBOLCOND{$tmpKey} = \@tmpSplit;
    }else
    {   $INCLUDESYMBOLMODE{$tmpKey} = 0;
    }
}   close INCLUDE;


# ------------------------------------------------------------------------------
#  File#05, EXCLUDE 	-- Symbols to be excluded (case insensitive)
# ------------------------------------------------------------------------------
# No mode is necessary for exclusion. they are all conditional
LogQuery( "! Loading \'EXCLUDE\' words ...");
my %EXCLUDESYMBOLCOND	= ();
while (<EXCLUDE>)
{   my $line 		= lc($_);
	$line 			=~ s/\r|\n//g;
    my @tmpSplit 	= split (/\t/, $line);
    my $tmpKey 		= $tmpSplit[0];
    my @newArray	= ();
    shift(@tmpSplit);    
    foreach my $excludeTerm (@tmpSplit)
	{	#  Remove special characters
		$excludeTerm =~ s/\:|\;|\.|\,|\-|\'|\"|\(|\)|\[|\]|\{|\}|\~|\!|\@|\$|\?|\<|\>|\+|\[|\/|\#/ /g;
		$excludeTerm =~ s/\s+/ /g;
		push @newArray, $excludeTerm;
		if (substr($excludeTerm, -1, 1) ne 's')
		{	push @newArray, $excludeTerm.'s';
		}
	}    

    $EXCLUDESYMBOLCOND{$tmpKey} 	= \@newArray;
    
    if ($tmpKey =~ /\-/)
    {   $tmpKey =~ s/\-//g;
        $EXCLUDESYMBOLCOND{$tmpKey} = \@newArray;
    }
    @tmpSplit	= ();
    undef @tmpSplit;
    undef $tmpKey;
}   close EXCLUDE;



# ------------------------------------------------------------------------------
#  File#06, HUGO Content 	-- Base HUGO content
# ------------------------------------------------------------------------------
LogQuery( "! Loading HUGO Content and handling splitted gene names ...");
my %ID2NameArray                        = ();   # ID2NameArray
my %ID2NameArrayType                    = ();   # 1 for full, 0 for partial match
my %PhenotypeOnlyToBeExcludedHUGOID     = ();
my %ID2geneID                           = ();   # Here geneID is the geneID in SciMinerDB
my @HUGOID                              = ();
my %HUGO2ApprovedSymbol                 = ();
my %HUGO2AllSymbol						= ();	# Now only approved but all
my %HUGO2ApprovedGeneName               = ();
my %HUGO2NCBIGeneID                     = ();
my %HUGO2PubMed                         = ();
my %lcHUGOSymbol2NCBIGeneID             = ();	# lowered HUGO Symbol ==> NCBI Gene ID

while (<IDCONTENT>)
{   my $line 	= $_;
	$line 		=~ s/\r|\n//g;
    my @temp	=split(/\t/,$line);
    if ( $temp[0] =~ /^\d/ )
    {	# ----------------------------------------------------------------------
		#   Column Index Description	-- Note that there is GeneID in the
		#								-- first column. 
		# ----------------------------------------------------------------------
		#	0	GeneID	1
		#	1	HGNCID	5
		#	2	Approved Symbol	A1BG
		#	3	Approved Name	alpha-1-B glycoprotein
		#	4	Status	Approved
		#	5	Locus Type	undef
		#	6	Previous Symbols	
		#	7	Previous Names	
		#	8	Aliases	
		#	9	Chromosome	19q
		#	10	Date Approved	30/06/1989
		#	11	Date Modified	7/2/2005
		#	12	Date Name Changed	
		#	13	Accession Numbers	
		#	14	Enzyme IDs	
		#	15	Entrez Gene ID	1
		#	16	MGD ID	
		#	17	Specialist Database Links	<!--,--> <!--,--> <!--,--> <!--,--> <!--,--> <!--,--> <!--,--> <!--,--> <!--,--> MEROPS:<a href="http://merops.sanger.ac.uk/cgi-bin/merops.cgi?id=I43.950">I43.950</a>
		#	18	Pubmed IDs	2591067
		#	19	RefSeq IDs	NM_130786
		#	20	Gene Family Name	
		#	21	GDB ID (mapped data)	GDB:119638
		#	22	Entrez Gene ID (mapped data)	1
		#	23	OMIM ID (mapped data)	138670
		#	24	RefSeq (mapped data)	NM_130786
		#	25	UniProt ID (mapped data)	P04217
		#	26	First_Group_Gene_Name	alpha-1-B
		#	27	NCBI_LocusLink_Symbols	A1BG<_>A1B<_>ABG<_>GAB<_>HYST2477<_>DKFZp686F0970<_>
		#	28	NCBI_LocusLink_Names	alpha-1-B glycoprotein<_>alpha 1B-glycoprotein<_>alpha-1B-glycoprotein<_>
		#	29	NCBI_GeneDB_Symbols	A1BG<_>A1B<_>ABG<_>DKFZp686F0970<_>GAB<_>HYST2477<_>
		#	30	NCBI_GeneDB_Name	alpha-1-B glycoprotein


		# ----------------------------------------------------------------------
		#  Assigning required ID hashes
		# ----------------------------------------------------------------------
		push @HUGOID, $temp[1];
        $ID2geneID{$temp[1]}                    = $temp[0];
        $HUGO2ApprovedSymbol{$temp[1]}          = $temp[2];
        $HUGO2ApprovedGeneName{$temp[1]}        = $temp[3];
        $HUGO2NCBIGeneID{$temp[1]}              = $temp[22];
        $HUGO2PubMed{$temp[1]}                  = $temp[18];
        $lcHUGOSymbol2NCBIGeneID{lc($temp[2])}  = $temp[22];
        
        my $hgncID          					= $temp[1];
        my $hugoSymbol      					= $temp[2];
        my $hugoName        					= $temp[3];
        my $locusLinkName   					= $temp[29];
        my $ncbiGeneDBNames 					= $temp[31];

		# ----------------------------------------------------------------------
		#  Check phenotype only for the record
		# ----------------------------------------------------------------------
        if ($temp[5] eq 'phenotype only')
        {   $PhenotypeOnlyToBeExcludedHUGOID{$temp[1]} = 1;
        }
        
		########################################################################
		#
		#  Collect gene names and process
		#
		########################################################################
        # ----------------------------------------------------------------------
		#  Process LocusLink names
        # ----------------------------------------------------------------------
        if ((defined $locusLinkName) && ($locusLinkName ne ""))
        {   my @namesSplit = split (/\<\_\>/, $locusLinkName);
            foreach my $word (@namesSplit)
            {   #  Skip any name shorter than '4' or same as the symbol of the gene
                if ((length($word)>=4) && (lc($hugoSymbol) ne lc($word)))
                {   if (not defined $ID2NameArray{$hgncID})
                    {   $ID2NameArray{$hgncID}->[0] = $word;
                        $ID2NameArrayType{$hgncID}->[0] = 1;
                    }else
                    {   push @{$ID2NameArray{$hgncID}}, $word;
                        push @{$ID2NameArrayType{$hgncID}}, 1;
                    }   
                    # Add additional names after removing special characters
                    $word =~ s/\(|\)|\,|\[|\]|\'/ /g;
                    $word =~ s/\s+/ /g;
                    push @{$ID2NameArray{$hgncID}}, $word;
                    push @{$ID2NameArrayType{$hgncID}}, 1;
                }   
            }
        }

        # ----------------------------------------------------------------------
		#  Process NCBI Gene DB names
        # ----------------------------------------------------------------------
        if ((defined $ncbiGeneDBNames) && ($ncbiGeneDBNames ne ""))
        {   my @namesSplit = split (/\<\_\>/, $ncbiGeneDBNames);
            foreach my $word ( @namesSplit)
            {   #  Skip any name shorter than '4' or same as the symbol of the gene
				if ((length($word)>=4) && (lc($hugoSymbol) ne lc($word)))
                {   if (not defined $ID2NameArray{$hgncID})
                    {   $ID2NameArray{$hgncID}->[0] = $word;
                        $ID2NameArrayType{$hgncID}->[0] = 1;
                    }else
                    {   push @{$ID2NameArray{$hgncID}}, $word;
                        push @{$ID2NameArrayType{$hgncID}}, 1;
                    }   
                    # Add additional names after removing special characters
                    $word =~ s/\(|\)|\,|\[|\]|\'/ /g;
                    $word =~ s/\s+/ /g;
                    push @{$ID2NameArray{$hgncID}}, $word;
                    push @{$ID2NameArrayType{$hgncID}}, 1;
                }   
            }
        }

		# ----------------------------------------------------------------------
		#  Add the HUGO official names to the ID2NameArray
        # ----------------------------------------------------------------------
        if (not defined $ID2NameArray{$hgncID})
        {   $ID2NameArray{$hgncID}->[0] = $hugoName;
            $ID2NameArrayType{$hgncID}->[0] = 1;
        }else
        {   push @{$ID2NameArray{$hgncID}}, $hugoName;
            push @{$ID2NameArrayType{$hgncID}}, 1;
        }   


        # ---------------------------------------------------------------------
        #  Generate more names withe first word(s) -- Use with caution.
        # ---------------------------------------------------------------------
        #  Split and add to the list
        $hugoName =~ s/\,|\'/ /g;   	 	# dash is not included
        $hugoName =~ s/\(|\)|\[|\]/ /g;
        $hugoName =~ s/\s+/ /g;				# remove double spaces	
        push @{$ID2NameArray{$hgncID}}, $hugoName;
        push @{$ID2NameArrayType{$hgncID}}, 1;

        # Handle the first word
        my @spaceSplit = split (/\s+/, $hugoName);
        my $firstWord = $spaceSplit[0];
        if (length($firstWord) >= 3)
        {   push @{$ID2NameArray{$hgncID}}, $firstWord;
            push @{$ID2NameArrayType{$hgncID}}, 0.3;
        }
        
        # Handle the second word if not in the ignorelist
		# Note that the minimum length is 3
        if (defined $spaceSplit[1])
        {   if ((not defined $ignoreWordOnly{lc($spaceSplit[1])}) && (length ($spaceSplit[1]) >= 3) &&
                ($spaceSplit[1] =~ /\w/))
            #if ((length ($spaceSplit[1]) >= 3) && ($spaceSplit[1] =~ /\w/))
            {   push @{$ID2NameArray{$hgncID}}, $spaceSplit[1];
                push @{$ID2NameArrayType{$hgncID}}, 0.3;
            }
            if ((defined $spaceSplit[2]) && (not defined $ignoreWordOnly{lc($spaceSplit[2])}) &&
                (length ($spaceSplit[2]) >= 3) && ($spaceSplit[2] =~ /\w/))
            {   push @{$ID2NameArray{$hgncID}}, $spaceSplit[2];
                push @{$ID2NameArrayType{$hgncID}}, 0.3;
            }

            # Handle the remaining words
            for (my $j=1; $j <= $#spaceSplit -1; $j++)
            {   $firstWord .= ' '.$spaceSplit[$j];
                push @{$ID2NameArray{$hgncID}}, $firstWord;
                push @{$ID2NameArrayType{$hgncID}}, 0.3;
            }
        }

#        # Process if '-' is included
#        if ($hugoName =~ /\-/)
#        {   $hugoName =~ s/\-/ /g;
#
#            # Handle the first word
#            @spaceSplit = split (/\s+/, $hugoName);
#            $firstWord = $spaceSplit[0];
#            if (length($spaceSplit[0]) >= 3)
#            {   push @{$ID2NameArray{$hgncID}}, $firstWord;
#                push @{$ID2NameArrayType{$hgncID}}, 0.3;
#            }
#            
#            # Handle the second word if not in the ignorelist
#            if (defined $spaceSplit[1])
#            {   if ((not defined $ignoreWordOnly{lc($spaceSplit[1])}) && (length ($spaceSplit[1]) >= 3) &&
#                    ($spaceSplit[1] =~ /\w/))
#                #if ((length ($spaceSplit[1]) >= 3) && ($spaceSplit[1] =~ /\w/))
#                {   push @{$ID2NameArray{$hgncID}}, $spaceSplit[1];
#                    push @{$ID2NameArrayType{$hgncID}}, 0.3;
#                }
#                if ((defined $spaceSplit[2]) && (not defined $ignoreWordOnly{lc($spaceSplit[2])}) &&
#                    (length ($spaceSplit[2]) >= 3) && ($spaceSplit[2] =~ /\w/))
#                {   push @{$ID2NameArray{$hgncID}}, $spaceSplit[2];
#                    push @{$ID2NameArrayType{$hgncID}}, 0.3;
#                }
#
#                # Handle the remaining words
#                for (my $j=1; $j <= $#spaceSplit -1; $j++)
#                {   $firstWord .= ' '.$spaceSplit[$j];
#                    push @{$ID2NameArray{$hgncID}}, $firstWord;
#                    push @{$ID2NameArrayType{$hgncID}}, 0.3;
#                }
#            }
#        }
    }
}   close IDCONTENT;



# ------------------------------------------------------------------------------
#  File#07, UNIQNAME Content 	
# ------------------------------------------------------------------------------
LogQuery( "! Loading unique gene names ...");
my %UNIQNAMEADDEDCHECK  = ();
my @UNIQNAME            = ();
my %UNIQNAME2HUGO       = ();
my %UNIQNAME2ORIGINAL   = ();

while ( <UNIQNAME> )
{   my $line    	= $_;                   
    $line       	=~ s/\r|\n//g;
    my @temp    	= split(/\t/,$line);

    my $name    	= lc($temp[0]);
    my $hugoID  	= $temp[1];
    my $source  	= $temp[2];
    my $originalStr = $name;
    
    #  Remove any flanking blank space of the name
    while(substr($name,-1,1) eq " ")
    {   substr($name,-1,1) = '';
    }
    
    #  Skip any name shorter than 4
    my $tmpLength   = length ($name);
    if ($tmpLength <= 3)
    {   next;
    }
    
	$name	= lc($name);
	    
    #  Check if the current name is in the ignore/english list // or already in the hash
    if ((defined $wordList{$name}) || (defined $UNIQNAME2HUGO{$name}))
    {   # No need to update
    }else
    {   # Special characters are removed
		# $name =~ s/\-/ /g;           # 12/2/2006: removing dash '-' is needed?
		$name =  lc(special_character_handling_for_hash_key($name));
		$name =~ s/\s+/ /g;
    	
    	push @UNIQNAME, $name;
        $UNIQNAME2HUGO{$name}               = $hugoID;
        $UNIQNAME2ORIGINAL{$name}           = $originalStr;
        
        ##  In case this name is not in the ID2NameArray (which is impossible)
        #if (not defined $ID2NameArray{$hugoID})
        #{   $ID2NameArray{$hugoID}->[0]     = $originalStr;
        #    $ID2NameArrayType{$hugoID}->[0] = 1;
        #}else
        #{   push @{$ID2NameArray{$hugoID}}, $originalStr;
        #    push @{$ID2NameArrayType{$hugoID}}, 1;
        #}
    }

    #  NOTE: I believe the following step has already been taken care of during
    #        dictionary generation step. But will leave this here just in case
    #  Func: Remove parenthes, commas, dashes are removed during this step. 
    #        The resulting name still has no special characters.
    #        
    my $newName = $originalStr;
    $newName =~ s/\-|\,|\(|\)|\{|\}/ /g;
    $newName =~ s/\s+/ /g;

    if ((defined $wordList{$newName}) || (defined $UNIQNAME2HUGO{$newName}))
    {   # No need to update
    }else
    {   $newName =  lc(special_character_handling_for_hash_key($newName));
		push @UNIQNAME, $newName;
        $UNIQNAME2HUGO{$newName} 			= $hugoID;
        $UNIQNAME2ORIGINAL{$newName} 		= $originalStr;
        if (not defined $ID2NameArray{$hugoID})
        {   $ID2NameArray{$hugoID}->[0]     = $originalStr;
            $ID2NameArrayType{$hugoID}->[0] = 1;
        }else
        {   push @{$ID2NameArray{$hugoID}}, $originalStr;
            push @{$ID2NameArrayType{$hugoID}}, 1;
        }
    }
}   close UNIQNAME;


# ------------------------------------------------------------------------------
# 03/30/2008 
# ------------------------------------------------------------------------------
#  Replace names ending with ' '+number like ' 1'
my $uniqueNameCount		= scalar @UNIQNAME;
my $additionalNameCnt	= 0;
LogQuery("! Initial unique name count = $uniqueNameCount");

my %withoutNumberEntry 	= ();
for (my $i=0; $i < $uniqueNameCount; $i++)
{   if ($UNIQNAME[$i] =~ /^(.*\D) (\d+)$/)
	{   my $baseString	= $1;
		my $tmpString	= $baseString.$2;
		
		if (not defined $UNIQNAME2HUGO{$baseString})
		{	$withoutNumberEntry{$baseString}	= 1;
		}
		
		if ((defined $wordList{$tmpString}) || (defined $UNIQNAME2HUGO{$tmpString}))
		{   # No need to update
		}else
		{   push @UNIQNAME, $tmpString;
			$UNIQNAME2HUGO{$tmpString}               = $UNIQNAME2HUGO{$UNIQNAME[$i]};
        	$UNIQNAME2ORIGINAL{$tmpString}           = $UNIQNAME2ORIGINAL{$UNIQNAME[$i]};
        	$additionalNameCnt++;
		}
	}
	
	if ($UNIQNAME[$i] =~ /^(.*\S) homolog (\S.*)$/)
	{   my $tmpString	= $1.' '.$2;
		
		if ((defined $wordList{$tmpString}) || (defined $UNIQNAME2HUGO{$tmpString}))
		{   # No need to update
		}else
		{   push @UNIQNAME, $tmpString;
			$UNIQNAME2HUGO{$tmpString}               = $UNIQNAME2HUGO{$UNIQNAME[$i]};
        	$UNIQNAME2ORIGINAL{$tmpString}           = $UNIQNAME2ORIGINAL{$UNIQNAME[$i]};
        	$additionalNameCnt++;
		}
		
		$tmpString	= $1.$2;
		if ((defined $wordList{$tmpString}) || (defined $UNIQNAME2HUGO{$tmpString}))
		{   # No need to update
		}else
		{   push @UNIQNAME, $tmpString;
			$UNIQNAME2HUGO{$tmpString}               = $UNIQNAME2HUGO{$UNIQNAME[$i]};
        	$UNIQNAME2ORIGINAL{$tmpString}           = $UNIQNAME2ORIGINAL{$UNIQNAME[$i]};
        	$additionalNameCnt++;
		}
	}
}
LogQuery("! Additional unique name added = $additionalNameCnt");
LogQuery("! Total unique names           = ".($uniqueNameCount+$additionalNameCnt));

# ------------------------------------------------------------------------------
#  	Create hashes for names by using the first 4 characters as indice.
# ------------------------------------------------------------------------------
LogQuery( "! Indexing gene name array ...");
my (%first4codeStart, %first4codeEnd, $tmpFirst4Code);
my $geneNameIndex = 0;
@UNIQNAME = sort (@UNIQNAME);
foreach (@UNIQNAME)
{   $tmpFirst4Code = substr($_, 0, 4);
    if (not defined $first4codeStart{$tmpFirst4Code})
    {   $first4codeStart{$tmpFirst4Code} = $geneNameIndex;
        $first4codeEnd{$tmpFirst4Code} = $geneNameIndex;
    }else
    {   # only update the end index
        $first4codeEnd{$tmpFirst4Code} = $geneNameIndex;
    }   $geneNameIndex++;
}   


# ------------------------------------------------------------------------------
#  	Remove redundancy of the ID2NamyArray
# ------------------------------------------------------------------------------
LogQuery("! Simplifying gene names (removing redundancy)...");
my $tmpCnt = 0;
my (%NonRedundantID2NameArray, %NonRedundantID2NameTypeArray);
foreach my $ID2NameArrayKey (keys %ID2NameArray)
{   my (%tmpID2NameArrayLocal, %tmpID2NameArrayTypeLocal);
    
    for (my $i=0; $i < scalar @{$ID2NameArray{$ID2NameArrayKey}}; $i++)
    {   # give the name occuring beforehand has a priority over than after one.
		# 01/29/2008: Co-occurring score is now completely based on the lowered
        my $tmpName	= lc(@{$ID2NameArray{$ID2NameArrayKey}}[$i]);
		if (not defined $tmpID2NameArrayLocal{$tmpName})
        {   $tmpID2NameArrayLocal{$tmpName} 	= 1;
            $tmpID2NameArrayTypeLocal{$tmpName} = @{$ID2NameArrayType{$ID2NameArrayKey}}[$i];
        }
        if ($tmpName =~ /\-/)
        {   $tmpName =~ s/\-/ /g;
            $tmpName =~ s/\s+/ /g;
            if (not defined $tmpID2NameArrayLocal{$tmpName})
            {   $tmpID2NameArrayLocal{$tmpName} 	= 1;
                $tmpID2NameArrayTypeLocal{$tmpName} = @{$ID2NameArrayType{$ID2NameArrayKey}}[$i];
            }
        }
    }

    my @tmpNameArray = keys %tmpID2NameArrayLocal;
    $NonRedundantID2NameArray{$ID2NameArrayKey} = \@tmpNameArray;
    for (my $i=0; $i < scalar @tmpNameArray; $i++)
    {   $NonRedundantID2NameTypeArray{$ID2NameArrayKey}->{$tmpNameArray[$i]} = $tmpID2NameArrayTypeLocal{$tmpNameArray[$i]};
    }
    undef %tmpID2NameArrayLocal;   undef %tmpID2NameArrayTypeLocal;
}

#foreach my $ID2NameArrayKey (keys %ID2NameArray)
#{   my (%tmpID2NameArrayLocal, %tmpID2NameArrayTypeLocal);
#    
#    for (my $i=0; $i < scalar @{$ID2NameArray{$ID2NameArrayKey}}; $i++)
#    {   # give the name occuring beforehand has a priority over than after one.
#        if (not defined $tmpID2NameArrayLocal{@{$ID2NameArray{$ID2NameArrayKey}}[$i]})
#        {   $tmpID2NameArrayLocal{@{$ID2NameArray{$ID2NameArrayKey}}[$i]} = 1;
#            $tmpID2NameArrayTypeLocal{@{$ID2NameArray{$ID2NameArrayKey}}[$i]} = 
#                @{$ID2NameArrayType{$ID2NameArrayKey}}[$i];
#        }
#        if (@{$ID2NameArray{$ID2NameArrayKey}}[$i] =~ /\-/)
#        {   @{$ID2NameArray{$ID2NameArrayKey}}[$i] =~ s/\-/ /g;
#            @{$ID2NameArray{$ID2NameArrayKey}}[$i] =~ s/\s+/ /g;
#            if (not defined $tmpID2NameArrayLocal{@{$ID2NameArray{$ID2NameArrayKey}}[$i]})
#            {   $tmpID2NameArrayLocal{@{$ID2NameArray{$ID2NameArrayKey}}[$i]} = 1;
#                $tmpID2NameArrayTypeLocal{@{$ID2NameArray{$ID2NameArrayKey}}[$i]} = 
#                    @{$ID2NameArrayType{$ID2NameArrayKey}}[$i];
#            }
#        }
#    }
#
#    my @tmpNameArray = keys %tmpID2NameArrayLocal;
#    $NonRedundantID2NameArray{$ID2NameArrayKey} = \@tmpNameArray;
#    for (my $i=0; $i < scalar @tmpNameArray; $i++)
#    {   $NonRedundantID2NameTypeArray{$ID2NameArrayKey}->{$tmpNameArray[$i]} = $tmpID2NameArrayTypeLocal{$tmpNameArray[$i]};
#    }
#    #print $tmpCnt."\t".$ID2NameArrayKey."\t".@{$ID2NameArray{$ID2NameArrayKey}}."\n";
#    undef %tmpID2NameArrayLocal;   undef %tmpID2NameArrayTypeLocal;
#}

# ------------------------------------------------------------------------------
#  File#08, UNIQSYM Content 	
# ------------------------------------------------------------------------------
LogQuery("! Loading unique symbols ...");
my (@atList, @atListHUGOID, @UNIQSYM, %UNIQSYM2HUGO, @UNIQSYMWithSpecialChar, 
    %UNIQSYMHASHLOWKEY2HUGO, %UNIQSYMHASHLOWKEY2ORIGINAL );
while ( <UNIQSYM> )
{   my $line = $_;          $line =~ s/\r|\n//g;
    my @temp = split(/\t/,$line);
	my $tmpOriginal = $temp[0];
	# Discard any gene symbol with the following characters
	# (, ), [, ], {, }, *, +, #, ,, 
	
	my $upConv 	= uc($temp[0]);
	if (( $upConv eq 'BETA') || ( $upConv eq 'ALPHA') || ( $upConv eq 'GAMMA') ||
		( $upConv eq 'KAPPA'))
	{   next;
	}
	
	if ($temp[0] =~ /\(|\)|\[|\]|\{|\}|\*|\+|\#|\,|\//) 
	{   # print "Symbol with special character $temp[0]\n";
		# ignore the symbol
		# NOTE: 09/27/2007: These symbols used to be ignored but not any more from now on. 
		#       09/27/2007: These symbols would have case-sensitive symbols.
		#       05/19/2008: special character is handled in a different way
		# my $newSymbol = special_character_handling_for_hash_key($temp[0]);
		my $newSymbol = $temp[0];
		
		push @UNIQSYMWithSpecialChar, $newSymbol;
		$UNIQSYM2HUGO{$newSymbol} = $temp[1];
        if (defined $wordList{lc($newSymbol)})
        {   # This one should be avoided in lower case
        }else
        {   $UNIQSYMHASHLOWKEY2HUGO{first_chr_keep_upper_other_lower_case($newSymbol)} = $temp[1];
		    $UNIQSYMHASHLOWKEY2ORIGINAL{first_chr_keep_upper_other_lower_case($newSymbol)} = $tmpOriginal;
        }
	}elsif ($temp[0] =~ /\@$/) 
	{   # In case of the last character is '@', put it aside for later check-up
        # print $temp[0]."\n";
		push @atList, $temp[0];
		push @atListHUGOID, $temp[1];
	}else
	{   # 10/08/06 added - Hash key
		# $temp[0] = special_character_handling_for_hash_key($temp[0]);
		push @UNIQSYM, $temp[0];
		
		$UNIQSYM2HUGO{$temp[0]} = $temp[1];
        if (defined $wordList{lc($temp[0])})
        {   # This one should be avoided in lower case
        }else
        {   $UNIQSYMHASHLOWKEY2HUGO{first_chr_keep_upper_other_lower_case($temp[0])} = $temp[1];
		    $UNIQSYMHASHLOWKEY2ORIGINAL{first_chr_keep_upper_other_lower_case($temp[0])} = $tmpOriginal;
        }
		
		#  Add hugo2allsymbol	-- Symbol is only in lower case
		#  06/29/2008 - not any more. case is preserved and searched against original text.
		if (not defined $HUGO2AllSymbol{$temp[1]})
		{	my @tmpArray				= ($temp[0]);
			$HUGO2AllSymbol{$temp[1]} 	= \@tmpArray;
		}else
		{	push @{$HUGO2AllSymbol{$temp[1]}}, $temp[0];
		}
	}
}   close UNIQSYM;


# ------------------------------------------------------------------------------
#  File#09, DUPSYM Content 		- duplicate symbol
# ------------------------------------------------------------------------------
#  In duplicate symbol, symbols are compared after being changed to lower-case
LogQuery( "! Loading duplicate symbols ...");
my (%DUPSYM2HUGO);
while ( <DUPSYM> )
{   my $line = $_;          $line =~ s/\r|\n//g;
    my @temp1 = split(/\t/,$line);
	my @temp2 = split(/\<\_\>/, $temp1[1]);
    
    # If the gene symbol contains any space or special character, discard it.
	# (, ), [, ], {, }, *, +, #, ,, 
    my %definedCheck = ();
	if ($temp1[0] =~ /\(|\)|\[|\]|\{|\}|\*|\+|\#|\,| |\@/) 
	{   # ignore the symbol
	    # NOTE: 09/27/2007: These symbols used to be ignored but not any more.
	    # NOTE: 10/05/2007: Well,, let's just ignore them for now. 
	    # $temp1[0] = special_character_handling_for_hash_key($temp1[0]);
	}else
	{   my @tmpArr      = ();
        my %dupCheck    = ();
        foreach my $dupIDPairStr (@temp2)
        {   my @temp3 = split (/\_\_/, $dupIDPairStr);
            if (not defined $dupCheck{$temp3[0]})
            {   push @tmpArr, $temp3[0];
                $dupCheck{$temp3[0]} = 1;
            }
            if (not defined $dupCheck{$temp3[1]})
            {   push @tmpArr, $temp3[1];
                $dupCheck{$temp3[1]} = 1;
            }
			
			# Add the symbol to the second gene for $HUGO2AllSymbol
			push @{$HUGO2AllSymbol{$temp3[1]}}, $temp1[0];
        }
		
		# ----------------------------------------------------------------------
		# Date: 01/29/2008
		# Check pre-existing entry and if any just add
		# Case-sensitive symbols like p14 and P14 are now merged
		# Previously, the last one was obviously used.
		if (not defined $DUPSYM2HUGO{lc($temp1[0])})
		{	$DUPSYM2HUGO{lc($temp1[0])} = \@tmpArr; 
		}else
		{	push @{$DUPSYM2HUGO{lc($temp1[0])}}, @tmpArr; 
		}
	}
}   close DUPSYM;


#  NOTE: 09/27/2007: There is no symbol ending with '@' any more in the SciMiner dictionary
#  Handle cases of symbols ending with '@'
#for (my $i=0; $i < scalar @atList; $i++) {
#    print "There are symbol with at sign $atList[$i]\n";
#	my $tmpKey = $atList[$i];
#	substr($tmpKey, -1, 1) = '';
#	if (defined $UNIQSYM2HUGO{$tmpKey}) {
#		# If already defined, simply discard this one but change the key
#       if ($HUGO2ApprovedSymbol{$UNIQSYM2HUGO{$tmpKey}} ne $tmpKey)
#        {   $HUGO2ApprovedSymbol{$UNIQSYM2HUGO{$tmpKey}} = $tmpKey;
#       }
#	}else
#   {   $UNIQSYM2HUGO{$tmpKey} = $atListHUGOID[$i];
#       $HUGO2ApprovedSymbol{$atListHUGOID[$i]}=$tmpKey;
#       if (defined $wordList{$tmpKey})
#       {   # This one should be avoided in lower case
#       }else
#       {   $UNIQSYMHASHLOWKEY2ORIGINAL{first_chr_keep_upper_other_lower_case($tmpKey)} = $tmpKey;
#		    $UNIQSYMHASHLOWKEY2HUGO{first_chr_keep_upper_other_lower_case($tmpKey)} = $atListHUGOID[$i];
#       }
#	}
#}


#  -----------------------------------------------------------------------------
#  03/30/2008
#  -----------------------------------------------------------------------------
#  Process additional unique symbols
#  ex) HP1-GAMMA	==> HP1G, HP1-gamma, HP1gamma, HP1GAMMA
#					(GAMMA, ALPHA, BETA) exclude KAPPA (only POL-KAPPA)
my $extendedSymbolCnt	= 0;
my $totalUNIQSYMCnt		= scalar @UNIQSYM;
LogQuery("! Original Symbol count = $totalUNIQSYMCnt");
LogQuery("! Processing unique symbol for variability...");

for (my $i=0; $i < $totalUNIQSYMCnt; $i++)
{	if ($UNIQSYM[$i] =~ /^(.*)-ALPHA$/)
	{   my $baseString	= $1;
		my $tmpString	= $baseString.'ALPHA';
		if (not defined $UNIQSYM2HUGO{$tmpString})
		{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
			$extendedSymbolCnt++;
		}
		
		$tmpString		= $baseString.'A';
		if (not defined $UNIQSYM2HUGO{$tmpString})
		{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
			$extendedSymbolCnt++;
		}
	}elsif ($UNIQSYM[$i] =~ /^(.*)-BETA$/)
	{   my $baseString	= $1;
		my $tmpString	= $baseString.'BETA';
		if (not defined $UNIQSYM2HUGO{$tmpString})
		{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
			$extendedSymbolCnt++;	
		}
		
		$tmpString		= $baseString.'B';
		if (not defined $UNIQSYM2HUGO{$tmpString})
		{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
			$extendedSymbolCnt++;
		}
	}elsif ($UNIQSYM[$i] =~ /^(.*)-GAMMA$/)
	{   my $baseString	= $1;
		my $tmpString	= $baseString.'GAMMA';
		if (not defined $UNIQSYM2HUGO{$tmpString})
		{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
			$extendedSymbolCnt++;
		}
		
		$tmpString		= $baseString.'A';
		if (not defined $UNIQSYM2HUGO{$tmpString})
		{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
			$extendedSymbolCnt++;
		}
	}elsif ($UNIQSYM[$i] =~ /kappa/i)
	{   my $baseString	= $`;
		my $followStr	= $';
		my $tmpString	= $baseString.'K'.$followStr;
		if (not defined $UNIQSYM2HUGO{$tmpString})
		{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
			$extendedSymbolCnt++;
		}
		
		$tmpString		= $baseString.'k'.$followStr;
		if (not defined $UNIQSYM2HUGO{$tmpString})
		{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
			$extendedSymbolCnt++;
		}
	}elsif ($UNIQSYM[$i] =~ /^(.*\d)([a-g])$/)
	{	my $baseString	= $1;
		my $tmpString	= $baseString.uc($2);
		if (not defined $UNIQSYM2HUGO{$tmpString})
		{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
			$extendedSymbolCnt++;
		}
	}elsif ($UNIQSYM[$i] =~ /^(.*\D)-(\d+)$/)
	{	my $baseString	= $1;
		my $tmpString	= $baseString.$2;
		if (not defined $UNIQSYM2HUGO{$tmpString})
		{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
			$extendedSymbolCnt++;
		}
	}elsif ($UNIQSYM[$i] =~ /^(\D+)\.(\d+)$/)
	{	my $baseString	= $1;
		my $tmpString	= $baseString.$2;
		if (not defined $UNIQSYM2HUGO{$tmpString})
		{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
			$extendedSymbolCnt++;
		}
	}elsif ($UNIQSYM[$i] =~ /^(.*\D)\-(\D+)$/)
	{	my $baseString	= $1;
		my $extString	= $2;
		if (($baseString !~ /-/) && ($extString !~ /-/))
		{   my $tmpString	= $baseString.$extString;
			if (not defined $UNIQSYM2HUGO{$tmpString})
			{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
				$extendedSymbolCnt++;
			}else
			{   $tmpString	= uc($tmpString);
				if (not defined $UNIQSYM2HUGO{$tmpString})
				{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
					$extendedSymbolCnt++;
				}
			}
		}
	}elsif($UNIQSYM[$i] =~ /^([p|P])(\d.*)$/)
	{	my $baseString		= $1;
		my $extString		= $2;
		my $tmpString		= '';
		
		if ($baseString eq 'p')
		{	$tmpString		= 'P'.$extString;
		}else
		{	$tmpString		= 'p'.$extString;
		}
		
		if (not defined $UNIQSYM2HUGO{$tmpString})
		{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
			$extendedSymbolCnt++;
		}else
		{   $tmpString	= uc($tmpString);
			if (not defined $UNIQSYM2HUGO{$tmpString})
			{	$UNIQSYM2HUGO{$tmpString} = $UNIQSYM2HUGO{$UNIQSYM[$i]};
				$extendedSymbolCnt++;
			}
		}
	}
}
LogQuery("! Extended Symbol count = $extendedSymbolCnt");
LogQuery("! Total Symbol count 	= ".($totalUNIQSYMCnt+$extendedSymbolCnt));

# ------------------------------------------------------------------------------
#  File#10, PARTNAMEBEGIN and PARTNAMEMIDDLE 	- Process name overlapping
# ------------------------------------------------------------------------------
#  Just user same hash before I acutally make use of the start and middle differently.
LogQuery("! Loading part_names...");
my %partNameHash		= ();
while(<PARTNAMEBEGIN>)
{   my $line = $_;
	$line =~ s/\r|\n//g;
	# Put this lower-char conversion temporarily
	$line = lc ($line);
	my @tmpSplit = split (/\t/, $line);
	if (not defined $partNameHash{$tmpSplit[0]})
	{   my @array = ();
		push @array, $tmpSplit[2], $tmpSplit[3];
		$partNameHash{$tmpSplit[0]} = \@array;
	}else
	{   push @{$partNameHash{$tmpSplit[0]}}, $tmpSplit[2], $tmpSplit[3];
	}
}   close PARTNAMEBEGIN;

while(<PARTNAMEMIDDLE>)
{   my $line = $_;
	$line =~ s/\r|\n//g;
	# Put this lower-char conversion temporarily
	$line = lc ($line);
	my @tmpSplit = split (/\t/, $line);
	if (not defined $partNameHash{$tmpSplit[0]})
	{   my @array = ();
		push @array, $tmpSplit[2], $tmpSplit[3];
		$partNameHash{$tmpSplit[0]} = \@array;
	}else
	{   push @{$partNameHash{$tmpSplit[0]}}, $tmpSplit[2], $tmpSplit[3];
	}
}   close PARTNAMEMIDDLE;


# ------------------------------------------------------------------------------
#  File#12, GENERIF 	- Loading NCBI GeneRif sentences
# ------------------------------------------------------------------------------
LogQuery("! Loading GeneRif data...");
my %ncbiGeneID2geneRifSentence     = ();
while(<GENERIF>)
{   my $line = $_;
	$line =~ s/\r|\n//g;
	my @tmpSplit = split (/\t/, $line);
	if (not defined $ncbiGeneID2geneRifSentence{$tmpSplit[0]})
	{   my @tmpArray    = ();
	    push @tmpArray, $tmpSplit[1];
	    $ncbiGeneID2geneRifSentence{$tmpSplit[0]} = \@tmpArray;
	}else
	{   push @{$ncbiGeneID2geneRifSentence{$tmpSplit[0]}}, $tmpSplit[1];
	}
}   close GENERIF;


my @tmpKeys = keys %NonRedundantID2NameArray;
foreach my $tttKey (@tmpKeys)
{	if ($tttKey =~ /[A-Z]/)
	{	LogAnalysis ("TTTTTT $tttKey has upper character");
	}
}


# ---------------------------------------------------------------------------
#      Part VIII.    Main Processing                      
# ---------------------------------------------------------------------------

# ----------------------------------------------------------------------------
#  Connect to database
# ----------------------------------------------------------------------------
my $dbh = DBI->connect($SciMinerDB, $username, $password, {PrintError => 0})
    || LogQuery ("Could not open database, ", $DBI::errstr);

LogQuery( "----- Starting to process gene symbols -----");
SciMinerDB_Symbol_Parsing (  \%annoENV,
                            $SciMinerCorpusDir, 
                            $SciMinerTempDir,
                            \%ID2geneID,
                            \%HUGO2ApprovedSymbol, 
                            \%HUGO2ApprovedGeneName,
                            \%HUGO2NCBIGeneID, 
                            \@UNIQSYM, 
                            \%UNIQSYM2HUGO, 
                            \@UNIQNAME, 
                            \%UNIQNAME2HUGO,
    						\%UNIQSYMHASHLOWKEY2HUGO, 
    						\%UNIQSYMHASHLOWKEY2ORIGINAL, 
    						\%UNIQNAME2ORIGINAL, 
    						\%ID2NameArray,
                            \%INCLUDESYMBOLMODE, 
                            \%INCLUDESYMBOLCOND, 
                            \%EXCLUDESYMBOLCOND,
                            \%PhenotypeOnlyToBeExcludedHUGOID,
                            \%DUPSYM2HUGO, 
                            \%NonRedundantID2NameArray, 
                            \%NonRedundantID2NameTypeArray,
                            $programName,
                            $dbh, 
                            \%pmid2docID,
                            \%lcHUGOSymbol2NCBIGeneID,
                            \%ncbiGeneID2geneRifSentence,
							$dbUpdateOption,
							\%HUGO2AllSymbol,
							$InputFileMode,
							\%wordList
                        );



LogQuery( "----- Starting to process gene names -----");
#  retrieve finding / or just use the text file?
#  We need to launch another script for sub-routine that takes care of filtering findings by scores and other filters
    
SciMinerDB_Name_Parsing   (   \%annoENV,
                            $SciMinerCorpusDir, 
                            $SciMinerTempDir,
                            \%ID2geneID,
                            \%HUGO2ApprovedSymbol, 
                            \%HUGO2ApprovedGeneName,
                            \@UNIQNAME, 
                            \%UNIQNAME2HUGO,
    						\%UNIQNAME2ORIGINAL, 
                            \%first4codeStart, 
                            \%first4codeEnd,
                            $programName,
                            $dbh, 
                            \%PhenotypeOnlyToBeExcludedHUGOID, 
                            \%pmid2docID,
                            \%partNameHash,
							$dbUpdateOption,
							\%EXCLUDESYMBOLCOND,
							$InputFileMode,
							\%wordList
                        );   



    #  Continue to the post-mining step in the original routine, 
    #  This is because the this script "SciMiner_FullMedline_Mining.pl" is 
    #  only focusing on the actual mining step and nothing else. 
    
    #  Nope, the post-step is going to happen here
    
    #  1)  check the user's manual selection
    #       exclusion list
    #       inclusion list
    #       ignore list
    #       a) first mark the difference between the default and user's input
    #       b) perform the EXCLUSION/INCLUSION filtering step again
    #           ba) if SQL can handle this case, do so.
    #               1) download full sentences of the PMIDs with the given gene selection
    #               2) check for any additional exclusion / inclusion
    #                   
    
    #  TODO: 1) write the result from mining into the given files
    #        2) download additional sentence2gene results to the files
    #        3) update the mining status in the SciMinerDB
    #        4) check user's manual selection  -- Last step

    
    
LogQuery ("All the mining process have been completed....");
exit;



