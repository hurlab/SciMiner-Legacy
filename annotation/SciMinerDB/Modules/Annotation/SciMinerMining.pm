#############################################################################
#
#   	Subroutin Collection for SciMiner Mining Part
#	
#	Written by : Junguk Hur	
#	
#############################################################################

use strict;
use warnings;


#  ---------------------------------------------------------------------------
#  ---------------------------------------------------------------------------
#
#  Section I.  Symbol (Acronym) Parsing Part
#
#  ---------------------------------------------------------------------------
#  ---------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# sub SciMinerDB_Symbol_Parsing
# ----------------------------------------------------------------------------
# Last modified : 01/18/2008
# Description   : This subroutin parses out gene SYMBOLS with flanking
#                 text surrounding mined names from full text content.
# ----------------------------------------------------------------------------
sub SciMinerDB_Symbol_Parsing
{   my ($annoENVRef, 
        $sourceDir, 
        $targetDir,
        $ID2SciMinerGeneID,
		$ID2SymbolHash, 
		$ID2NameHash,
		$ID2GeneIDHash, 
		$UNIQSYMArray, 
		$UNIQSYM2IDHash,
		$UNIQNAMEArray, 
		$UNIQNAME2IDHash,
		$UNIQSYMHASHLOWKEY2HUGO, 
		$UNIQSYMHASHLOWKEY2ORIGINAL, 
		$UNIQNAMEHASHLOWKEY2ORIGINAL, 
        $ID2NameArray, 
        $INCLUDESYMBOLMODE, 
        $INCLUDESYMBOLCOND, 
        $EXCLUDESYMBOLCOND,
        $PhenotypeOnlyToBeExcludedHUGOID,
        $DUPSYM2HUGO, 
        $NonRedundantID2NameArray, 
        $NonRedundantID2NameTypeArray, 
        $programName, 
        $dbh,
        $pmid2docIDRef,
        $lcHUGOSymbol2NCBIGeneIDRef,
        $entrezGeneID2geneRifSentenceRef,
		$dbUpdateOption,
		$HUGO2AllSymbolRef,
		$InputFileMode,
		$wordListRef					)= @_; 
        
	my ($pubmedID, $abstract, $title, @titleSplit,
		@abstractLineSplit, @foundHUGOContent, $foundHUGONumber);

	#  Check $InputFileMode for standlone mode
	if (not defined $InputFileMode)
	{   $InputFileMode = '';
	}

    #  Set Column String to be inserted
    my $colNameString           = "pmid, senID, geneID, hgncID, approvedSymbol, matchString, actualString, startPos, score, flankingText, matchCodeID, tag, SciMinerVersion, SciMinerMethod, inExClude, inExCludeCond, phenotypeOnly, conflictCode, hgncIDbyNR, NRText";
    my $colNameStringConflict   = "sen2geneID, geneID, hgncID, rawScore, rankByScore, NRFreqScore, RankByNRFreq";
    
    #  Search option
    my $checkFlankingGeneProteinOption  = 1;        # This is to enable check adjacent possible genes.
    my $checkSameBlockAdjacentGene      = 1;        # This is to give some score if any of them is zero while the other is not.
    my $checkGeneSymbolLength           = 6;        # This is the minimum length of symbols to be included regardless of the score.
    
    #  NCBI GeneRif term frequency hash
    my %entrezGeneID2geneRifTermFreq    	= ();       # This would be used for all documents.
	my %entrezGeneID2geneRifTermTotalCount	= ();
    my %wordToExcludeForTermFreqCalc    	= ();       # These are the terms to be excluded like we , are, at , etc
    
    define_word_to_exclude_for_frequency(\%wordToExcludeForTermFreqCalc);
    

    # ------------------------------------------------------------------------
	#      Gene Symbol Search Mode 
	# ------------------------------------------------------------------------
    my @fileName = glob ($sourceDir."/*.preSciMiner");
    
    #  Prepare output file and get the PMID list from files
    my $outFileName = $targetDir.'SciMinerBase.out';
	open (RESULT, ">".$outFileName) || LogQuery("!ERROR: SciMinerDB_Symbol_Parsing Can't write to file $outFileName");
	my @shortFileName = shortFileNameExtraction (\@fileName);
    my @PMIDList = ();
    for (my $i=0; $i <= $#shortFileName ; $i++) 
    {   my @tmp = split (/\./, $shortFileName[$i]);
        $PMIDList[$i] = $tmp[0];
    }
    
    
    #  Loop over every file
    for (my $fileNum = 0; $fileNum <= $#fileName; $fileNum++) 
    {   open ( FILE, $fileName[$fileNum] ) || LogQuery("!ERROR: SciMinerDB_Symbol_Parsing Can't open file $fileName[$fileNum]");
        #print $fileName[$fileNum]."\n";
		my $tmpParagraphString = '';
        my @targetSentences = ();

		# my $targetSentenceStart = 0;
        # Gather meaningful full text area
        # Sections to be extracted; every section except Reference. But reference can happen before figure or table. Thus figure/table should be checked
        my @senIDs              = ();
        my %senID2anchor        = ();
        my %senID2sentence      = ();
        my $wholeTextContent    = '';
		my $wholeTextContentLW  = '';
		
        #  REMOVE: There is no reference section any more in JUMInerDB, Thus the following step is unnecessary
        #          (only read the sentence into memory)
        while ( <FILE> )
        {   my $line=$_;        $line =~ s/\r|\n//g;
            if ($line =~ /^(\d+) (\S+) (\w+) (\d+) p (\d+) /)
            {   if (($3 eq 'PMID') || ($3 eq 'REFERENCE') || ($3 eq 'REFERENCES') || ($3 eq 'ACKNOWLEDGMENTS') || ($3 eq 'AUTHORS'))
            	{   next;
            	}

                #  MESHRN text is only used for scoring purpose
                if ($3 ne 'MESHRN')
                {   push @senIDs, $1;
					$senID2anchor{$1}   = $3;
					$senID2sentence{$1} = $'.' ';   #'
                }
            	#$wholeTextContent .= $senID2sentence{$1};
                $wholeTextContent .= $'.' ';
            }
        }   close FILE;
        $wholeTextContentLW			= lc($wholeTextContent);
        $wholeTextContentLW			=~ s/\?|\.|\,|\-|\/|\\|\(|\)|\[|\]|\{|\}|\`|\'|\"|\:|\;|\!|\@|\#|\$|\%|\^|\&|\*|\~/ /g;
        $wholeTextContentLW			=~ s/\s+/ /g;
        
        #  Now proceed with gene symbol search.
        #  This will be done sentence-wise manner. So the result will be updated at after sentence is completely processed. 
        
        my %coExistScore            = ();
        my @zeroScoredMatch         = ();
        my @semiFinalMatch          = ();
        
        #  Exclusion/Inclusion list applies to all the sentence
        my %exclusionStatus         = ();
        my %exclusionCond           = ();                       # only the first exclusion is enough if any
        my %inclusionStatus         = ();
        my %inclusionCond           = ();        
        my %hugoID2score            = ();
        my %coExistScoreMatch       = ();
        my %coExistScoreHUGOID      = ();
        
        #  Term frequency counting for name-resolving purpose
        my %matchTerm2TermFreq      = ();
        my %docTermFreq             = ();
        my %matchTermSentenceCount  = ();
           
                
        #  --------------------------------------------------------------------
		#  Special Change 	: Pre-filtering any possible symbols followed by
		#                     selected terms 
		#  Date				: 10/30/2008
		#  Scope			: Single document
		#  --------------------------------------------------------------------
		my @filteringTerms			= (	"et al", "buffer", "score", "version", "medium",
										"media", "cells", "software", "program", "algorithm",
										"system", "test", "company", "agent" );

		my $symbolsToFilterOutHashRef	= collect_symbols_to_be_filtered_out (\$wholeTextContentLW, \@filteringTerms);
		
		
        #  Loop over every sentence             
        foreach my $senID (@senIDs)
        {   #  Identify symbol
            #  Mine the sentence for any symbol and default coExistScore.
            my ($sentence2geneRef) = extract_symbol_case_sensitive($PMIDList[$fileNum], $senID, \%senID2anchor, \%senID2sentence, 
            										\$wholeTextContentLW, \$wholeTextContent,
                                                    $UNIQSYM2IDHash, $UNIQNAME2IDHash, $ID2SymbolHash, 3, 
                                                    $UNIQSYMHASHLOWKEY2HUGO, $UNIQSYMHASHLOWKEY2ORIGINAL, $ID2NameArray,
                                                    $NonRedundantID2NameArray, $NonRedundantID2NameTypeArray, $ID2GeneIDHash, \%coExistScore,         
                                                    $DUPSYM2HUGO, \%hugoID2score, \%coExistScoreMatch, \%coExistScoreHUGOID,
                                                    \%matchTerm2TermFreq, \%matchTermSentenceCount, \%docTermFreq,
						    						$HUGO2AllSymbolRef, $wordListRef, $symbolsToFilterOutHashRef);
            
            #$$ref[0] = HUGO ID
		    #$$ref[1] = matching word
		    #$$ref[2] = actual word
		    #$$ref[3] = matching position
		    #$$ref[4] = score
		    #$$ref]5] = match code
		    #$$ref[6] = SciMiner method code
		    #$$ref[7] = flanking text

			#+--------------+----------------+
			#| methodCodeID | methodCodeType |
			#+--------------+----------------+
			#|            1 | SYMBOL         | 
			#|            2 | NAME           | 
			#+--------------+----------------+
		    
			#+-------------+------------------------------+
			#| matchCodeID | matchCodeType                |
			#+-------------+------------------------------+
			#|           1 | exact_match                  | 
			#|           2 | lower_match                  | 
			#|           3 | word_gene_protein_mRNA       | 
			#|           4 | same_word_block              | 
			#|           5 | flanking_gene_1              | 
			#|           6 | flanking_gene_2              | 
			#|           7 | name_lower                   | 
			#|          10 | h|m_and_capitals_like_hSin3a | 
			#|          11 | processed_dash               | 
			#|          12 | alpha_beta_gamma_kappa       | 
			#|          13 | plural_forms                 | 
			#|          14 | lower_to_higher_matching     | 
			#|          15 | further_grouping_with_and_to | 
			#+-------------+------------------------------+

            #  There was at least one match (symbol) found            
            if (defined $$sentence2geneRef[0])
            {   #  Process matching words starting with '-';
            	#  Remove any starting '-'
            	foreach my $ref (@{$sentence2geneRef})
            	{   if ($$ref[2] =~ /^-/)
		        	{	$$ref[2] = $';
		        		# LogQuery("Starting dash has been removed to $$ref[2]");
		        	}
            	}
            	
            	#  ------------------------------------------------------------------------------
                #    Perform additional score calculation based on the context
                #  ------------------------------------------------------------------------------
                #  1. Look for adjacent 'gene(s)' / 'protein(s)' / mRNA(s) '
                #     ==> maybe we can add something like 'receptor(s) for' but currently only use gene and protein
                if ($checkFlankingGeneProteinOption)
                {   foreach my $ref (@{$sentence2geneRef})
                    {   my $flankGeneScore = Calculate_Flanking_Word_Score_For_Gene(\$wholeTextContent, $$ref[2]);
                        if (($$ref[4] == 0) && ($flankGeneScore > 0))
                        {   $$ref[5] = 3;
                        }
                        #  Add the flank score anyway
                        $$ref[4] += $flankGeneScore;
                    }
                }
                
                # -------------------------------------------------------------------------------
                #  2. Look for any other gene in the same word block
                #     ?? Do I have to do this check only for zero-scored match?
                my %pos2scoreCheck          = ();
                my @localZeroScoredMatch    = ();
                my @tmpNonZeroScoredMatch   = ();
                
                if ($checkSameBlockAdjacentGene)
                {   foreach my $ref (@{$sentence2geneRef})
                    {   if ($$ref[4] > 0)
                        {   $pos2scoreCheck{$$ref[3]} = $$ref[4];
                            push @tmpNonZeroScoredMatch, $ref;
                        }else
                        {   push @localZeroScoredMatch, $ref;
                            next;
                        }
                    }
                    
                    #  3. Look for any adjacent gene up to two words distance of gene symbols with score > 0
                    #  Now check the score of adjacent words
                    #  For those zero-score match, add $senID to the array
                    if (defined $localZeroScoredMatch[0])
                    {   foreach my $ref (@localZeroScoredMatch)
                        {   #  If it is in the same word with other gene, this probably mean a gene forming a complex or alternative name
                            if ((($$ref[3]-1)>=0) && (defined $pos2scoreCheck{($$ref[3]-1)}))
                            {   $$ref[5] = 5;
                                $$ref[4] += 0.2;
                                #print "in same block $$ref[1] at position ",($$ref[3]-1)," and the score is $pos2scoreCheck{($$ref[3]-1)}\n";
                            }
                            if (defined $pos2scoreCheck{($$ref[3]+1)})
                            {   $$ref[5] = 5;
                                $$ref[4] += 0.2;
                            }
                            if ((($$ref[3]-2)>=0) && (defined $pos2scoreCheck{($$ref[3]-2)}))
                            {   $$ref[5] = 6;
                                $$ref[4] += 0.1;
                            }
                            if (defined $pos2scoreCheck{($$ref[3]+2)})
                            {   $$ref[5] = 6;
                                $$ref[4] += 0.1;
                            }
                            if (defined $pos2scoreCheck{$$ref[3]})
                            {   #  This case is the symbol is in the same block with other gene
                                $$ref[5] = 4;
                                $$ref[4] += 0.3;
                            }

                            #push @{$ref}, $senID;
                            push @tmpNonZeroScoredMatch, $ref;
                        }
                    }
                }else
                {   @tmpNonZeroScoredMatch = @{$sentence2geneRef};
                }
            
                #  Add the senID to the end of the each array
                foreach my $ref (@tmpNonZeroScoredMatch)
                {   push @{$ref}, $senID;
                    push @semiFinalMatch, $ref;
                }
            }   #  End of if (defined $$sentence2geneRef[0])
        }   #  End of foreach my $senID (@senIDs)
        

        #  --------------------------------------------------------------------------------------------
        #  TODO: Do not use the maximum score assignment. 
        #  Note: max score is not used since it would be
        #  Now take care of the flanking gene score
        #my %maxBySymbol     = ();
        #foreach my $ref (@zeroScoredMatch)
        #{   #  First get the maximum of that symbol (matched String)
        #    if (not defined $maxBySymbol{$$ref[1]})
        #    {   $maxBySymbol{$$ref[1]} = $$ref[3];
        #    }else
        #    {   if ($maxBySymbol{$$ref[1]} < $$ref[3])
        #        {   $maxBySymbol{$$ref[1]} = $$ref[3];
        #        }
        #    }
        #}
        
        ##  Now use the calculated maximum for all matched symbol. 
        ##  This way, same symbol will have the same score (flanking_gene)
        #foreach my $ref (@zeroScoredMatch)
        #{   #  First get the maximum of that symbol (matched String)
        #    $$ref[3] = $maxBySymbol{$$ref[1]};
        #    foreach my $string (@{$ref})
        #    {   print $string."\t";
        #    }   print "\n";
        #
        #    my $command = "INSERT INTO `sentence2gene` ($colNameString) VALUES ($PMIDList[$fileNum], $$ref[7], $$ID2SciMinerGeneID{$$ref[0]}, $$ref[0], \"$$ID2SymbolHash{$$ref[0]}\", \"$$ref[1]\", \"$$ref[2]\", $$ref[3], $$ref[4], \"\", $$ref[5], \"\", \"$programName\", \"$$ref[6]\")";
        #    print $command."\n\n";
        #    $dbh->do($command);
        #    
        #}
        
        
        #  -------------------------------------------------------------------
        #  Check cases to exclude (thanks/acknowledge/et al/codon/cell lines
        #  -------------------------------------------------------------------                
        #  inclusion/exclusion will ALWAYS be performed for any new sentence
        
        #mysql> select * from inexcode;
        #+----------+-----------+
        #| inExCode | inExDesc  |
        #+----------+-----------+
        #|        1 | Inclusion | 
        #|        2 | Exclusion | 
        #|        0 | Default   | 
        #+----------+-----------+
        #3 rows in set (0.00 sec)
        #
        #mysql> select * from inexdetail;
        #+--------------+-------------------------------------+
        #| inExDetailID | inExDetailTerm                      |
        #+--------------+-------------------------------------+
        #|           32 | cell line                           | 
        #|           33 | acknowledgements                    | 
        #|           34 | et al                               | 
        #|           35 | nucleotide codons                   | 
        #|           31 | exclusion list                      | 
        #|           11 | inclusion list                      | 
        #|           12 | symbol longer than specified length | 
        #+--------------+-------------------------------------+
        #7 rows in set (0.00 sec)


	
		
        my %conflictingSymbol2SenID     = ();       # double hash
        my %conflictSymbolResolvedID    = ();       # 
        my %conflictSymbolResolvedText  = ();
        foreach my $ref (@semiFinalMatch)
        {   my $tmpGeneSymbol   = lc($$ref[1]);     # $$ref[1] is the registered matching string

            #  Collect conflicting symbols (use  which is lowered)
            #  Note that senID is at index of 8
            if (defined $$DUPSYM2HUGO{$tmpGeneSymbol})
            {   if (not defined $conflictingSymbol2SenID{$tmpGeneSymbol})
                {   my %tmpHash         = ();
                    $tmpHash{$$ref[8]}  = 1;
                    $conflictingSymbol2SenID{$tmpGeneSymbol}    = \%tmpHash;
                }else
                {   $conflictingSymbol2SenID{$tmpGeneSymbol}->{$$ref[8]} = 1;
                }
            }
            
            #  Start to check with inclusion/exclusion list            
            my $tmpInExCode     = 0;
            my $tmpInExDetail   = 0;
        	#  Always check advancing word 'thank(s)' for any positive scored symbol. 
        	#  Is this really necessary? Yes, we can illiminate some of the false-positives
        	#  But in terms of processing time, wouldn't this ????
        	#  This only applies when the matchcode is 2 ==> Lowered match. 
        	if ($$ref[4] > 0) 
        	{   if ($$ref[5] == 2)      # matchcode is 2
        		{   if (($$ref[7] =~ /thanks?/) || ($$ref[7] =~ /acknowledge/))
	        	    {   # There is the word 'thank/s/', then probably matching symbol is very likely to be a false-positive if it's matched by lowered
	        	    	# Don't change the score, just update the status
	        	    	# $$ref[4] = 0;
	        	    	$tmpInExCode        = 2;
	        	    	$tmpInExDetail      = 33;
	        	    }
	        	    
	        	    # !_! The following section has been deleted on 10/30/2008 
	        	    #     since this is now checked by collect_symbols_to_be_filtered_out
	        	    #elsif ($$ref[7] =~ /$$ref[2] et al\b/)
	        	    #{	#$$ref[4] = 0;
	        	    #    #if ($$ref[7] =~ /$$ref[2]\b(\S*\s?){0,3} et al/)
	        	    #    #{   #  There is such terms with Symbol (lowered) <up to two more words> et al
	        	    #    #    $$ref[4] = 0;
	        	    #    #}
	        	    #	$tmpInExCode        = 2;
	        	    #	$tmpInExDetail      = 34;	        	        
	        	    #}
        		}
        		
        		#elsif ($$ref[7] =~ /[C|c]ell/)
        	    #{   #  Check for any occurrence of cell line related format
        	    #    if (check_cell_line_name($$ref[2], $$ref[7]))
        	    #    {   $tmpInExCode    = 2;
        	    #        $tmpInExDetail  = 32;	
        	    #    }
        	    #}
				
				#  --------------------------------------------------------------------------------
	            #  Check if the symbol is simply a codon or not
	            if ($$ref[1] =~ /^[AGCTU]{3}$/i)
	        	{   if ($$ref[7] =~ /([ACGTU]{3}\s{0,1}){2,}/i)
	        		{   # The symbol belongs to codons
	        			# set the score zero
	        			# $$ref[4] = 0;
	        		    $tmpInExCode    = 2;
        	            $tmpInExDetail  = 35;	
	        		}
	        	}
				
        	}
        	
            if ($$ref[4] > 0)
            {   #  If the score is greater than zero
                #  In this case, the gene is checked against the EXCLUDE list
                #  Exclusion is ALWAYS conditional, thus no need to check mode.
                if ($tmpInExCode == 2)
                {   #  Check any customary inclusion list
                    if (defined $$INCLUDESYMBOLMODE{$tmpGeneSymbol})
                    {   #  Inclusion had higher priority before but not any more
						#   01/30/2008
						#if ( $$INCLUDESYMBOLMODE{$tmpGeneSymbol} )                  # if 1 ==> conditional
                        #{   if (not defined $inclusionStatus{$tmpGeneSymbol})
                        #    {   ($inclusionStatus{$tmpGeneSymbol}, $inclusionCond{$tmpGeneSymbol}) = SciMiner_check_inclusion_list (\$wholeTextContent, $$INCLUDESYMBOLCOND{$tmpGeneSymbol});
                        #    }else
                        #    {   #  This symbol already has inclusion Status and condition calculated.
                        #    }
                        #}else                                                       # else is non-conditional ==> just include
                        #{   # No need to check condition. just include them
                        #    $inclusionStatus{$tmpGeneSymbol}    = 1;
                        #    $inclusionCond{$tmpGeneSymbol}      = $tmpGeneSymbol.';';
                        #}
                        # 
                        ##  Add the inclusion information to the current element.
                        #push @{$ref}, $inclusionStatus{$tmpGeneSymbol}, $inclusionCond{$tmpGeneSymbol};
						push @{$ref}, $tmpInExCode, $tmpInExDetail;
                    }else
                    {   #  This entry has already been marked to be excluded
                        push @{$ref}, $tmpInExCode, $tmpInExDetail;
                    }
                }elsif (defined $$EXCLUDESYMBOLCOND{$tmpGeneSymbol})
                {   if (not defined $exclusionStatus{$tmpGeneSymbol})
                    {   ($exclusionStatus{$tmpGeneSymbol}, $exclusionCond{$tmpGeneSymbol}) = SciMiner_check_exclusion_list (\$wholeTextContent, $$EXCLUDESYMBOLCOND{$tmpGeneSymbol});
                    }else
                    {   #  This symbol already has exclusion Status and condition calculated.
                    }
                    #  Add the inclusion information to the current element.
                    push @{$ref}, $exclusionStatus{$tmpGeneSymbol}, $exclusionCond{$tmpGeneSymbol};
                }else
                {   #  This mined symbol is not currently included in the EXCLUSION list
                    #  Nothing more to do at this moment. 
                    push @{$ref}, 0, "";
                }
            }else
            {   #  If the score is not greater than zero, ==> the score is zero.
                #  In this case, the gene is checked against the INCLUDE list
                if (defined $$INCLUDESYMBOLMODE{$tmpGeneSymbol})
                {   if ( $$INCLUDESYMBOLMODE{$tmpGeneSymbol} )                  # if 1 ==> conditional
                    {   if (not defined $inclusionStatus{$tmpGeneSymbol})
                        {   ($inclusionStatus{$tmpGeneSymbol}, $inclusionCond{$tmpGeneSymbol}) = SciMiner_check_inclusion_list (\$wholeTextContent, $$INCLUDESYMBOLCOND{$tmpGeneSymbol});
                        }else
                        {   #  This symbol already has inclusion Status and condition calculated.
                        }
                    }else                                                       # else is non-conditional ==> just include
                    {   # No need to check condition. just include them
                        $inclusionStatus{$tmpGeneSymbol}    = 1;
                        $inclusionCond{$tmpGeneSymbol}      = $tmpGeneSymbol.';';
                    }
                    
                    #  Add the inclusion information to the current element.
                    push @{$ref}, $inclusionStatus{$tmpGeneSymbol}, $inclusionCond{$tmpGeneSymbol};
                }else
                {   #  This mined symbol is not currently included in the INCLUDE list
                    #  Check the symbol length check option. 
                    #  If the option is on and the symbol is not included in the EXCLUSION list mark it as INCLUDE
                    if ($checkGeneSymbolLength)
                    {   if (length($tmpGeneSymbol) >= $checkGeneSymbolLength)
                        {   #  Only include when it's not in the EXCLUSION list
                            if (not defined $exclusionStatus{$tmpGeneSymbol})
                            {   ($exclusionStatus{$tmpGeneSymbol}, $exclusionCond{$tmpGeneSymbol}) = SciMiner_check_exclusion_list (\$wholeTextContent, $$EXCLUDESYMBOLCOND{$tmpGeneSymbol});
                            }
                            
                            if ($exclusionStatus{$tmpGeneSymbol})
                            {   #  This symbol is in the exclusion list
                                push @{$ref}, $exclusionStatus{$tmpGeneSymbol}, $exclusionCond{$tmpGeneSymbol};
                            }else
                            {   #  Add this as LongSymbol inclusion; code = 2
                                push @{$ref}, 1, "LongSymbol";
                            }
                        }else
                        {   #  If the length is shorter than the threshold, still check the exclusion condition.
							if (not defined $exclusionStatus{$tmpGeneSymbol})
                            {   ($exclusionStatus{$tmpGeneSymbol}, $exclusionCond{$tmpGeneSymbol}) = SciMiner_check_exclusion_list (\$wholeTextContent, $$EXCLUDESYMBOLCOND{$tmpGeneSymbol});
                            }
                            
                            if ($exclusionStatus{$tmpGeneSymbol})
                            {   #  This symbol is in the exclusion list
                                push @{$ref}, $exclusionStatus{$tmpGeneSymbol}, $exclusionCond{$tmpGeneSymbol};
                            }else
                            {   #  Add this as LongSymbol inclusion; code = 2
                                push @{$ref}, 0, "";
                            }
                        }
                    }else
                    {	# if length option is not used, then simply check for exclusion condition
						if (not defined $exclusionStatus{$tmpGeneSymbol})
                        {   ($exclusionStatus{$tmpGeneSymbol}, $exclusionCond{$tmpGeneSymbol}) = SciMiner_check_exclusion_list (\$wholeTextContent, $$EXCLUDESYMBOLCOND{$tmpGeneSymbol});
                        }
                        
                        if ($exclusionStatus{$tmpGeneSymbol})
                        {   #  This symbol is in the exclusion list
                            push @{$ref}, $exclusionStatus{$tmpGeneSymbol}, $exclusionCond{$tmpGeneSymbol};
                        }else
                        {   #  Add this as LongSymbol inclusion; code = 2
                            push @{$ref}, 0, "";
                        }
                    }
                }
            }   #  End of else  
        }   #  End of foreach my $ref (@semiFinalMatch)


        #  Update SciMinerDB
        #if (defined $nonZeroScoredMatch[0])
        #{   foreach my $ref (@nonZeroScoredMatch)
        #    {   print RESULT $PMIDList[$fileNum]."\t".$senID."\t".$$ID2SciMinerGeneID{$$ref[0]}."\t".$$ref[0]."\t".$$ID2SymbolHash{$$ref[0]}."\t".$$ref[1]."\t".$$ref[2]."\t".$$ref[3]."\t".$$ref[4]."\t"."\t".$$ref[5]."\t"."\t".$programName."\t".$$ref[6]."\n";
        #        my $command = "INSERT INTO `sentence2gene` ($colNameString) VALUES ($PMIDList[$fileNum], $senID, $$ID2SciMinerGeneID{$$ref[0]}, $$ref[0], \"$$ID2SymbolHash{$$ref[0]}\", \"$$ref[1]\", \"$$ref[2]\", $$ref[3], $$ref[4], \"\", $$ref[5], \"\", \"$programName\", \"$$ref[6]\")";
        #        print $$ID2SymbolHash{$$ref[0]},"\t".$$ID2NameHash{$$ref[0]}."\n";
        #        print $command."\n\n";
        #        $dbh->do($command);
        #    }
        #}
            
        #my %conflictingSymbol2SenID     = ();       # double hash
        #my %conflictSymbolResolvedID    = ();       # 
        #my %conflictSymbolResolvedText  = (); 


        #  --------------------------------------------------------------------            
        #  Select only symbols to be checked by name_resolver
        #  --------------------------------------------------------------------
		my %nameResolverToBeAppliedLC	=();
		foreach my $ref (@semiFinalMatch)
		{	#  Positive score and not in exclusion list
			#  Or zero score but in the inclusion list ($$ref[9] == 1)
			if (($$ref[4] > 0) && ($$ref[9] != 2))
			{	$nameResolverToBeAppliedLC{lc($$ref[1])}	= 1;
			}elsif (($$ref[4] == 0) && ($$ref[9] == 1))
			{	$nameResolverToBeAppliedLC{lc($$ref[1])}	= 1;
			}
		}
		
		

		## !_! The following section has been deleted on 10/30/2008			
		##  --------------------------------------------------------------------            
        ##  Conflict-Name-Resolving
        ##  --------------------------------------------------------------------       
        #my %conflictCodeBySymbolLC      = ();
		#my %bestHGNCIDByNRSymbolLC		= ();
        #my %conflictTextBySymbolLC      = (); 
        #foreach my $conflictingSymbol (keys %conflictingSymbol2SenID)
        #{   #  Here we apply name-resolving strategy based on the term frequency of reference GeneRif
		#	#  Only if the score is non-zero and not belongs to exclusion
        #    ($conflictCodeBySymbolLC{$conflictingSymbol},
		#	 $bestHGNCIDByNRSymbolLC{$conflictingSymbol},
        #     $conflictTextBySymbolLC{$conflictingSymbol})  = name_resolving_generif_based
		#								(	$conflictingSymbol2SenID{$conflictingSymbol},
		#									\%senID2sentence, 
		#									\%matchTerm2TermFreq,
		#									\%matchTermSentenceCount,
		#									\%docTermFreq,
		#									$DUPSYM2HUGO,
		#									$conflictingSymbol, 
		#									$ID2GeneIDHash,
		#									$dbh, 
		#									$lcHUGOSymbol2NCBIGeneIDRef,
		#									$entrezGeneID2geneRifSentenceRef,
		#									\%entrezGeneID2geneRifTermFreq,
		#									\%entrezGeneID2geneRifTermTotalCount,
		#									\%wordToExcludeForTermFreqCalc,
		#									$ID2SymbolHash);
        #}

		#  --------------------------------------------------------------------            
        #  Process phenotypeOnly symbol and SciMinerDB Data Insertion
        #  --------------------------------------------------------------------       
        foreach my $ref (@semiFinalMatch)
        {	#  Check the current ref column count
        	my $colCount = scalar @{$ref};
        	
        	#  Add phenotypeOnly information
			if (defined $$PhenotypeOnlyToBeExcludedHUGOID{$$ref[0]})
            {   push @{$ref}, 1;
            }else
            {   push @{$ref}, 0;
            }
            
			#  -----------------------------------------------------------------
            #  Add name conflict resolver status and code description
			#  -----------------------------------------------------------------
			#	0	: no conflict
			#	1	: there is conflict but couldn't be resolved by nameresolver
			#		  due to the lack of GeneRif / NCBI ID information.
			#		  Or available number of geneRif genes is less than 2. ==> Not enough to compare
			# 	2	: Successfully resolved
			#	3	: Scores were 0. Couldn't determine which is better.
			#  -----------------------------------------------------------------
            
            # !_! The following section has been deleted on 10/30/2008
            #if (defined $conflictCodeBySymbolLC{lc($$ref[1])})
            #{   push @{$ref}, $conflictCodeBySymbolLC{lc($$ref[1])}, $bestHGNCIDByNRSymbolLC{lc($$ref[1])}, $conflictTextBySymbolLC{lc($$ref[1])};            
            #}else
            #{   push @{$ref}, "0", "", "";
            #}
            
            push @{$ref}, "0", "", "";
            $colCount = scalar @{$ref};

            
			#  -----------------------------------------------------------------
            #  ref index explanation	(As of 01/30/2008)
			#  -----------------------------------------------------------------
			#	$$ref[0]	:	hugoID
			#	$$ref[1]	:	matching word
			#	$$ref[2]	:   actual word
			#	$$ref[3]	:	matching position
			#	$$ref[4]	:	score
			#	$$ref[5]	:	matchCode
			#	$$ref[6]	:	SciMiner method code
			#	$$ref[7]	:	FlankingText
			#	$$ref[8]	:	senID
			#	$$ref[9]	:	inExCode
			#	$$ref[10]	:	inExCludeCondition
			#	$$ref[11]	:	phenotypeOnly
			#	$$ref[12]	:	ConflictCode (0, 1, 2, 3)
			#	$$ref[13]	:	NR - best hugoID
			#	$$ref[14]	:	Name Resolver Test
			#  -----------------------------------------------------------------
            #  Insert mined gene info into the SciMinerDB (sentence2gene table)
			#  -----------------------------------------------------------------
            
            #  Modify double quotation marks in the flanking text
            $$ref[7] =~ s/\"/\\\"/g;
            
			my $command = "INSERT INTO `sentence2gene` ($colNameString) VALUES ($PMIDList[$fileNum], $$ref[8], $$ID2SciMinerGeneID{$$ref[0]}, $$ref[0], \"$$ID2SymbolHash{$$ref[0]}\", \"$$ref[1]\", \"$$ref[2]\", $$ref[3], $$ref[4], \"$$ref[7]\", $$ref[5], \"\", \"$programName\", \"$$ref[6]\", $$ref[9], \"$$ref[10]\", $$ref[11], $$ref[12], \"$$ref[13]\", \"$$ref[14]\")";

			my $outputStr		= 	"$PMIDList[$fileNum]\t$$ref[8]\t$$ID2SciMinerGeneID{$$ref[0]}\t$$ref[0]\t$$ID2SymbolHash{$$ref[0]}\t".
									"$$ref[1]\t$$ref[2]\t$$ref[3]\t$$ref[4]\t$$ref[7]\t".
									"$$ref[5]\t\t$programName\t$$ref[6]\t$$ref[9]\t".
									"$$ref[10]\t$$ref[11]\t$$ref[12]\t$$ref[13]\t$$ref[14]\n";
			if ($dbUpdateOption == 0)
			{	print RESULT 	$outputStr;
			}else
			{	if ($InputFileMode)
				{	#  When the SciMiner is in the standalone mode
					#  Do not update the database
					print RESULT "0"."\t".$outputStr;
				}else
				{   $dbh->do($command) || LogQuery("ErrorInsertion $command");
            
					#  Retrieve the sen2geneID for this entry
					my $sth                 = $dbh->prepare("SELECT sen2geneID FROM sentence2gene ORDER BY sen2geneID DESC LIMIT 1");
					$sth->execute();
				
					my @row                 = $sth->fetchrow_array;	#($result);
					# LogQuery($row[0]."\t".$outputStr);
					
					if (defined $row[0])
					{	print RESULT 			$row[0]."\t".$outputStr;
					}
				}
			}
        }

        #  Now, finally update the SciMinerDB
        if (!$InputFileMode)
        {   $dbh->do("UPDATE document SET statusMined=1 WHERE docID = $$pmid2docIDRef{$PMIDList[$fileNum]}");
        }
    #  End of the loop every file    
    }   close RESULT;
	
}  # End of Subroutin HUGO_Symbol_Name_Parsing








#  ---------------------------------------------------------------------------
#  sub collect_symbols_to_be_filtered_out
#  ---------------------------------------------------------------------------
#  Last modified: 10/31/2008
#  Description: This will check for the content if there is any terms to be 
#				filtered based on the accompanying terms
#  Return: A hash reference of such filtered terms
#  ---------------------------------------------------------------------------
sub collect_symbols_to_be_filtered_out
{	my $wholeTextContentLWRef		= shift;
	my $filteringTermsRef			= shift;
	
	#  First screening for any existence
	my @termsToBeChecked			= ();
	my %symbolsToBeExcludedHash		= ();
	foreach my $term (@{$filteringTermsRef})
	{	if ($$wholeTextContentLWRef =~ / $term/)
		{	push @termsToBeChecked, $term;
		}
	}
	
	#  Second round to extract
	my $tmpFullContent				= '';
	foreach my $term (@termsToBeChecked)
	{	$tmpFullContent				= $$wholeTextContentLWRef;
		while ($tmpFullContent	=~ /(\S+) $term/)
		{	$symbolsToBeExcludedHash{$1}	= 1;
			$tmpFullContent		= $';
		}
	}
	
	#  Check the length of hash keys and delete if shorter than 3 characters
	foreach my $key (keys %symbolsToBeExcludedHash)
	{	if ((length $key) < 3)
		{	delete $symbolsToBeExcludedHash{$key};
		}
	}
	
	return (\%symbolsToBeExcludedHash);
} 





#  ---------------------------------------------------------------------------
#  sub extract_symbol_case_sensitive
#  ---------------------------------------------------------------------------
#  Last modified: 01/18/2008
#  Description: This subroutin perform the comparing task. This is called
#               by HUGO_Symbol_Name_Parsing
#  Return: An array of matched result
#  ---------------------------------------------------------------------------
sub extract_symbol_case_sensitive
{   my ($pmid, 
        $senID, 
        $senID2anchorRef, 
        $senID2sentenceRef, 
        $wholeTextContentLWRef,
        $wholeTextContentRef,
        $UNIQSYM2IDHash, 
        $UNIQNAME2IDHash,
        $ID2SymbolHash, 
        $lenThresh, 
		$UNIQSYMHASHLOWKEY2HUGO, 
		$UNIQSYMHASHLOWKEY2ORIGINAL, 
		$ID2NameArray,
        $NonRedundantID2NameArray, 
        $NonRedundantID2NameTypeArray, 
        $ID2GeneIDHashRef,
        $coExistScoreRef, 
        $DUPSYM2HUGORef,
        $hugoID2scoreRef,
        $coExistScoreMatchRef,
        $coExistScoreHUGOIDRef,
        $matchTerm2TermFreqRef,
        $matchTermSentenceCountRef,
        $docTermFreqRef,
		$HUGO2AllSymbolRef,
		$wordListRef,
		$symbolsToFilterOutHashRef
		) = @_;
        
	my @localFinding            = ();
	
	#  Remove character counting for faster processing
	#  Remove the ending '.'
    if (substr($$senID2sentenceRef{$senID}, -1, 1) eq '.')
    {   substr($$senID2sentenceRef{$senID}, -1, 1) = '';
    }
    
    #  Isoform upper hash
    my %isoformUpperHash	= ( "alpha" => "A", "beta" => "B", 
    						    "gamma" => "G", "kappa" => "K",
    							"dependent" => "", "specific" => "",
    							"receptor" => "R", "inducible" => "",
    							"staining" => "", "induced" => "",
    							"activated" => "", "repressed" => "",
    							"stimulated" => "", "captured" => "",
    							"regulated" => "", "controlled" => "",
    							"enhanced" => "", "like" => "",
    							"mediated" => "" );
    #  -related has been removed (06/23/08)		
    #  if this is to be reverted, |related| should be added to the matching ptrn.					
    

	#  Pre-define the position
	my @oriSplitBySpace     = split (/\s+/, $$senID2sentenceRef{$senID});
	my @sentence_split      = ();
	my @word_positions      = ();
	my @lowered_split_space = ();
	
	
	for (my $i=0; $i <= $#oriSplitBySpace; $i++)
	{   if ($oriSplitBySpace[$i] =~ /\-$/)
	    {   #  If the word ends with -, then try to merge the next word
	    	#  Merge this word with accompanying word
	    	#  Dangerous? What if there is something like AAA- and BBB-related
	        
	        if ($oriSplitBySpace[$i+1] !~ /(\band\b|\bor\b|\bto\b)/i)
	        {	my $tmpJoint = $oriSplitBySpace[$i].$oriSplitBySpace[$i+1];
			    $tmpJoint =~ s/[\(|\)|\{|\}|\[|\]|\+|\?|\!|\,|\;|\:|\||\/|\"]/ /g;
			    my @newJointSplit = split (/\s+/, $tmpJoint);
			    foreach my $string (@newJointSplit)
			    {   if ((defined $string) && ($string ne ""))
			        {   push @sentence_split, $string;
			            push @word_positions, $i;
			            push @lowered_split_space, lc($string);
			        }
			    }

			    #  Need to increase the $i to skip the right next one which has just been merged. 
			    $i++;
	        }else
	        {	push @sentence_split, $oriSplitBySpace[$i];
	    		push @word_positions, $i;
	    		push @lowered_split_space, lc($oriSplitBySpace[$i]);
	        }
	    }else
	    {   #  Remove the last period if any
	    	if ($oriSplitBySpace[$i] =~ /\.$/)
	    	{   substr($oriSplitBySpace[$i], -1, 1) = '';
	    	}
	    	
	    	#  03/30/2008
	    	#  First add anything with slash '/' as a whole
	    	if ($oriSplitBySpace[$i] =~ /\//)
	    	{   push @sentence_split, $oriSplitBySpace[$i];
	    		push @word_positions, $i;
	    		push @lowered_split_space, lc($oriSplitBySpace[$i]);
	    	}
	    	
	    	#  Second add anything with  '(' as a whole
	    	elsif ($oriSplitBySpace[$i] =~ /\(/)
	    	{   push @sentence_split, $oriSplitBySpace[$i];
	    		push @word_positions, $i;
	    		push @lowered_split_space, lc($oriSplitBySpace[$i]);
	    		
	    		if ($oriSplitBySpace[$i] =~ /\((\d+)\)$/)
	    		{	my $tmpTerm		= $`.$1;
	    			push @sentence_split, $tmpTerm;
					push @word_positions, $i;
					push @lowered_split_space, lc($tmpTerm);
	    		}
	    	}

			##  Third add anyting whith '-' as a whole	    	
	    	#if ($oriSplitBySpace[$i] =~ /\-/)
	    	#{	my $tmpString		= $oriSplitBySpace[$i];
	    	#	$tmpString			=~ s/[\(|\)|\{|\}|\[|\]|\+|\?|\!|\,|\;|\:|\||\/]/ /g;
	    	#	
	    	#	push @sentence_split, $tmpString;
	    	#	push @word_positions, $i;
	    	#	push @lowered_split_space, lc($oriSplitBySpace[$i]);
	    	#}
	    	
	    	#  Process special characters
	    	$oriSplitBySpace[$i] =~ s/[\(|\)|\{|\}|\[|\]|\+|\?|\!|\,|\;|\:|\||\/|\"]/ /g;
	        my @newSplit = split (/\s+/, $oriSplitBySpace[$i]);
	        foreach my $string (@newSplit)
	        {   if ((defined $string) && ($string ne ""))
	            {   push @sentence_split, $string;
	                push @word_positions, $i;
	                push @lowered_split_space, lc($string);
	            }
	        }
	    }
	}
		
		
	
	#  Match Code
	#	1	exact_match
	#	2	lower_match
	#	3	word_gene_protein_mRNA
	#	4	same_word_block
	#	5	flanking_gene_1
	#	6	flanking_gene_2
	#	7	name_lower
	#	10	h|m_and_capitals_like_hSin3a
	#	11	processed_dash
	#	12	alpha_beta_gamma_kappa
	#	13	plural_forms
	#	14	lower_to_higher_matching
	#	15	further_grouping_with_and_to


	my %gene2term2freq          = ();
    my %coExistScore            = ();               #  This is based on symbol
    #my %coExistScoreByHUGOID    = ();              #  This is based on HUGO ID
    my @sentence2gene           = ();
    my %conflictFound           = ();
    my $matchFound				= '';
    
	for (my $i=0; $i <= $#sentence_split ; $i++) 
    {   #if ((defined $sentence_split[($i+1)]) && 
    	#	($sentence_split[($i+1)] =~ /^(medium|media|camera|buffer|cell|solution|software|program|company)/i))
    	#{	# Skip this symbol since these are probably not symbols
    	#	next;
    	#}
    	
    	#  Check for filtered symbol list
    	if (defined $$symbolsToFilterOutHashRef{lc($sentence_split[$i])})
    	{	#  Skip any word(?) if it belongs to the filtering list 
    		#  These are marked to be having an accompanying word in any part of the text
    		#  such as medium, software, and etc. It's slightly different from above step
    		#  since this deals with full document level while the above only deals with immediate.
    		next;
    	}
    	
    	if ( defined $$DUPSYM2HUGORef{lc($sentence_split[$i])})
        {   $conflictFound{lc($sentence_split[$i])}    = 1;
        }
    
        my $matchCode 	= 1;
        my $methodCode	= 1;
        $matchFound		= '';
		if (length($sentence_split[$i]) >= $lenThresh)
		{   #  -----------------------------------------------------------------
			#  STEP - 1 : Exact symbol match
			#  -----------------------------------------------------------------
			if (defined $$UNIQSYM2IDHash{$sentence_split[$i]}) 
			{   #  First, check if the score is pre-defined. If it's predifined then we don't need to worry about conflicting symbol
			    my $bestHUGOID          = $$UNIQSYM2IDHash{$sentence_split[$i]};
			    my $bestScore           = -1;
				$matchFound				= $sentence_split[$i]; 
				
				if (not defined $$coExistScoreRef{$sentence_split[$i]})
			    {   #  If the coExistScore is not defined, then conflicting symbol must be checked.
			        if ( defined $$DUPSYM2HUGORef{lc($sentence_split[$i])})
    			    {   #  This will give you an array reference for hugo IDs assigned to this symbol
                        #  Let's calculate the co-existence score of the hugo IDs in this array
                        
                        my @conflictHUGOIDs     = @{$$DUPSYM2HUGORef{lc($sentence_split[$i])}};
                        for (my $j=0; $j <= $#conflictHUGOIDs; $j++)
                        {   if (not defined $$hugoID2scoreRef{$conflictHUGOIDs[$j]})
                            {   $$hugoID2scoreRef{$conflictHUGOIDs[$j]}     = SciMiner_CoExist_Score_Calculate_With_Symbol(
                            													$wholeTextContentLWRef, $wholeTextContentRef,
                            													$sentence_split[$i],
                                                                                $$NonRedundantID2NameArray{$conflictHUGOIDs[$j]}, 
                                                                                $$NonRedundantID2NameTypeArray{$conflictHUGOIDs[$j]},
																				$HUGO2AllSymbolRef, $conflictHUGOIDs[$j]);		# deduction of 0.5 for same symbol
                            }

                            #  Compare this score with the current maximum and update if necessary
                            if ( $$hugoID2scoreRef{$conflictHUGOIDs[$j]} > $bestScore)
                            {   $bestScore      = $$hugoID2scoreRef{$conflictHUGOIDs[$j]};
                                $bestHUGOID     = $conflictHUGOIDs[$j];
                            }                 
                        }
    			    }else
    			    {   #  If there is no conflict, then just calculate the score
    			        if (not defined $$hugoID2scoreRef{$bestHUGOID})
                        {   $$hugoID2scoreRef{$bestHUGOID} = SciMiner_CoExist_Score_Calculate_With_Symbol(
                        										$wholeTextContentLWRef, $wholeTextContentRef,
                        										$sentence_split[$i],
                                                                $$NonRedundantID2NameArray{$bestHUGOID}, 
                                                                $$NonRedundantID2NameTypeArray{$bestHUGOID},
																$HUGO2AllSymbolRef, $bestHUGOID);
                        }
                        $bestScore = $$hugoID2scoreRef{$bestHUGOID};
    			    }
    			    
    			    #  We finally have a score and hugoID (if there was a conflict) for this specific symbol $sentence_split[$i])
    			    $$coExistScoreRef{$sentence_split[$i]}          = $bestScore;
    			    $$coExistScoreMatchRef{$sentence_split[$i]}     = $matchCode;
    			    $$coExistScoreHUGOIDRef{$sentence_split[$i]}    = $bestHUGOID;
			    }else
			    {   $bestScore  = $$coExistScoreRef{$sentence_split[$i]}; 
			        $matchCode  = $$coExistScoreMatchRef{$sentence_split[$i]}; 
			        $bestHUGOID = $$coExistScoreHUGOIDRef{$sentence_split[$i]}; 
			    }

		    

			    #  Add the current finding to the final result array @sentence2gene
                if (not defined $sentence2gene[0])
			    {   $sentence2gene[0]->[0]  = $bestHUGOID;
			    }else
			    {   $sentence2gene[$#sentence2gene+1]->[0] = $bestHUGOID;
			    }
                push @{$sentence2gene[$#sentence2gene]}, $sentence_split[$i];
                push @{$sentence2gene[$#sentence2gene]}, $sentence_split[$i];
                push @{$sentence2gene[$#sentence2gene]}, $word_positions[$i];
                push @{$sentence2gene[$#sentence2gene]}, $bestScore;
                push @{$sentence2gene[$#sentence2gene]}, $matchCode;            # score match code    
                push @{$sentence2gene[$#sentence2gene]}, $methodCode;           # overall SciMiner methodCode
                push @{$sentence2gene[$#sentence2gene]}, get_flanking_text_for_symbol_match(\@sentence_split, $i, 10);
			}
			
			
			#  -----------------------------------------------------------------
			#  STEP - 2 : Lower-case converted (Only from the second characters)
			#  -----------------------------------------------------------------
			#  ex) TNF (originally human) ==> Tnf (mouse, rat, and etc)
			elsif (defined $$UNIQSYMHASHLOWKEY2HUGO{$sentence_split[$i]}) 
			{	#  For lower-case converted first character symbol, use the half of the original symbol
			    #  ex) MPG -> score = 1      ==> Mpg -> score = 1/2     This is very arbitary to give higher score to the case-sensitive one. 
			    #  First, check if the score is pre-defined. If it's predifined then we don't need to worry about conflicting symbol

				my $bestHUGOID          = $$UNIQSYMHASHLOWKEY2HUGO{$sentence_split[$i]};
			    my $bestScore           = 0;
			    my $tmpUpperCaseKey     = $$UNIQSYMHASHLOWKEY2ORIGINAL{$sentence_split[$i]};
			    $matchCode 				= 2;
			    $matchFound				= $sentence_split[$i];
			    
			    #  Check whether this symbol has a coExistScore
			    if (not defined $$coExistScoreRef{$sentence_split[$i]})
                {   if (defined $$coExistScoreRef{$tmpUpperCaseKey})
                    {   #  Use the full score of the full symbol. Not just half.
                        $bestHUGOID     = $$coExistScoreHUGOIDRef{$tmpUpperCaseKey}; 
                        $bestScore      = $$coExistScoreRef{$tmpUpperCaseKey}; 
                    }else
                    {   if (defined $$DUPSYM2HUGORef{lc($sentence_split[$i])})
        			    {   #  This will give you an array reference for hugo IDs assigned to this symbol
                            #  Let's calculate the co-existence score of the hugo IDs in this array
                            my @conflictHUGOIDs     = @{$$DUPSYM2HUGORef{lc($sentence_split[$i])}};
                            for (my $j=0; $j <= $#conflictHUGOIDs; $j++)
                            {   if (not defined $$hugoID2scoreRef{$conflictHUGOIDs[$j]})
                                {   $$hugoID2scoreRef{$conflictHUGOIDs[$j]}     = SciMiner_CoExist_Score_Calculate_With_Symbol(
                                													$wholeTextContentLWRef, $wholeTextContentRef, 
                                													$sentence_split[$i],
                                													$$NonRedundantID2NameArray{$conflictHUGOIDs[$j]}, 
                                                                                    $$NonRedundantID2NameTypeArray{$conflictHUGOIDs[$j]},
																					$HUGO2AllSymbolRef, $conflictHUGOIDs[$j]);
                                }
                                
                                #  Compare this score with the current maximum and update if necessary
                                if ( $$hugoID2scoreRef{$conflictHUGOIDs[$j]} > $bestScore)
                                {   $bestScore      = $$hugoID2scoreRef{$conflictHUGOIDs[$j]};
                                    $bestHUGOID     = $conflictHUGOIDs[$j];
                                }                 
                            }
        			    }else
        			    {   #  If there is no conflict, then just calculate the score
        			        if (not defined $$hugoID2scoreRef{$bestHUGOID})
                            {   $$hugoID2scoreRef{$bestHUGOID} = SciMiner_CoExist_Score_Calculate_With_Symbol(
                            										$wholeTextContentLWRef,  $wholeTextContentRef,
                            										$sentence_split[$i],
                                                                    $$NonRedundantID2NameArray{$bestHUGOID}, 
                                                                    $$NonRedundantID2NameTypeArray{$bestHUGOID},
																	$HUGO2AllSymbolRef, $bestHUGOID);
                            }
                            $bestScore = $$hugoID2scoreRef{$bestHUGOID};
        			    }
                    	
                        #  Assign both current symbol $sentence_split[$i] and $tmpUpperCaseKey                    
                        $$coExistScoreRef{$sentence_split[$i]}          = $bestScore;
        			    $$coExistScoreHUGOIDRef{$sentence_split[$i]}    = $bestHUGOID;
           			    $$coExistScoreMatchRef{$sentence_split[$i]}     = $matchCode;

                        $$coExistScoreRef{$tmpUpperCaseKey}             = $bestScore;
                        $$coExistScoreHUGOIDRef{$tmpUpperCaseKey}       = $bestHUGOID;
                        $$coExistScoreMatchRef{$tmpUpperCaseKey}        = 1;
                    }
                }else
                {   #  If there is coExistScore for this symbol, there is nothing we should do more since everything has already been done before.
                    $bestScore      = $$coExistScoreRef{$sentence_split[$i]};
                    $bestHUGOID     = $$coExistScoreHUGOIDRef{$sentence_split[$i]};
                }
			    
			    #  Add the current finding to the final result array @sentence2gene
                if (not defined $sentence2gene[0])
			    {   $sentence2gene[0]->[0]  = $bestHUGOID;
			    }else
			    {   $sentence2gene[$#sentence2gene+1]->[0] = $bestHUGOID;
			    }
                push @{$sentence2gene[$#sentence2gene]}, $tmpUpperCaseKey;
                push @{$sentence2gene[$#sentence2gene]}, $sentence_split[$i];
                push @{$sentence2gene[$#sentence2gene]}, $word_positions[$i];
                push @{$sentence2gene[$#sentence2gene]}, $bestScore;
                push @{$sentence2gene[$#sentence2gene]}, $matchCode;            # score match code    
                push @{$sentence2gene[$#sentence2gene]}, $methodCode;                     # overall SciMiner methodCode
                push @{$sentence2gene[$#sentence2gene]}, get_flanking_text_for_symbol_match(\@sentence_split, $i, 10);
			}
			
			#  -----------------------------------------------------------------
			#  STEP - 3 : h|m and Capitals like hSin3a or hPop1 (POP1)
			#  -----------------------------------------------------------------
			#  03/30/2008 
			#  New tagging algorithm: symbol starting with 'h' and 
			#  followed by capital letter. Check for symbol without 'h' or 'm'
			
			elsif ($sentence_split[$i] =~ /^[h|m]([A-Z].*)/)
			{	#  remove the first h|m and make the remaining to all upper case
			    #  ex) SIN3A 	-> score = 1      	==> mSin3a 	-> score = 1     
			    #  ex) POP1		-> score = 1		==> hPop1	-> score = 1
				my $tmpQueryString			= $1;
			    my $originalQueryString		= $sentence_split[$i];
			    $matchCode					= 10;

				#  Check if there is a HUGO ID matched
				if (not defined $$UNIQSYM2IDHash{$tmpQueryString}) 
				{	if (not defined $$wordListRef{lc($tmpQueryString)})
					{	# At least, this is not a every day English word
						$tmpQueryString		= uc ($tmpQueryString);
					}
				}
				
				if (defined $$UNIQSYM2IDHash{$tmpQueryString}) 
				{   # tmpIsoform First, check if the score is pre-defined. If it's predifined then we don't need to worry about conflicting symbol
					my $bestHUGOID          = $$UNIQSYM2IDHash{$tmpQueryString};
					my $bestScore           = -1;
					$matchFound				= $tmpQueryString;   
					if (not defined $$coExistScoreRef{$tmpQueryString})
					{   #  If the coExistScore is not defined, then conflicting symbol must be checked.
					    if ( defined $$DUPSYM2HUGORef{lc($tmpQueryString)})
					    {   #  This will give you an array reference for hugo IDs assigned to this symbol
		                    #  Let's calculate the co-existence score of the hugo IDs in this array
		                    my @conflictHUGOIDs     = @{$$DUPSYM2HUGORef{lc($tmpQueryString)}};
		                    for (my $j=0; $j <= $#conflictHUGOIDs; $j++)
		                    {   if (not defined $$hugoID2scoreRef{$conflictHUGOIDs[$j]})
		                        {   $$hugoID2scoreRef{$conflictHUGOIDs[$j]}     = SciMiner_CoExist_Score_Calculate_With_Symbol(
		                        													$wholeTextContentLWRef,  $wholeTextContentRef,
		                        													$tmpQueryString,
		                                                                            $$NonRedundantID2NameArray{$conflictHUGOIDs[$j]}, 
		                                                                            $$NonRedundantID2NameTypeArray{$conflictHUGOIDs[$j]},
																					$HUGO2AllSymbolRef, $conflictHUGOIDs[$j]);		# deduction of 0.5 for same symbol
		                        }

		                        #  Compare this score with the current maximum and update if necessary
		                        if ( $$hugoID2scoreRef{$conflictHUGOIDs[$j]} > $bestScore)
		                        {   $bestScore      = $$hugoID2scoreRef{$conflictHUGOIDs[$j]};
		                            $bestHUGOID     = $conflictHUGOIDs[$j];
		                        }                 
		                    }
					    }else
					    {   #  If there is no conflict, then just calculate the score
					        if (not defined $$hugoID2scoreRef{$bestHUGOID})
		                    {   $$hugoID2scoreRef{$bestHUGOID} = SciMiner_CoExist_Score_Calculate_With_Symbol(
		                    										$wholeTextContentLWRef,  $wholeTextContentRef,
		                    										$tmpQueryString,
		                                                            $$NonRedundantID2NameArray{$bestHUGOID}, 
		                                                            $$NonRedundantID2NameTypeArray{$bestHUGOID},
																	$HUGO2AllSymbolRef, $bestHUGOID);
		                    }
		                    $bestScore = $$hugoID2scoreRef{$bestHUGOID};
					    }
					    
					    #  We finally have a score and hugoID (if there was a conflict) for this specific symbol $tmpQueryString)
					    $$coExistScoreRef{$tmpQueryString}          = $bestScore;
					    $$coExistScoreMatchRef{$tmpQueryString}     = $matchCode;
					    $$coExistScoreHUGOIDRef{$tmpQueryString}    = $bestHUGOID;
					}else
					{   $bestScore  = $$coExistScoreRef{$tmpQueryString}; 
					    $matchCode  = $$coExistScoreMatchRef{$tmpQueryString}; 
					    $bestHUGOID = $$coExistScoreHUGOIDRef{$tmpQueryString}; 
					}

				

					#  Add the current finding to the final result array @sentence2gene
		            if (not defined $sentence2gene[0])
					{   $sentence2gene[0]->[0]  = $bestHUGOID;
					}else
					{   $sentence2gene[$#sentence2gene+1]->[0] = $bestHUGOID;
					}
		            push @{$sentence2gene[$#sentence2gene]}, $tmpQueryString;
		            push @{$sentence2gene[$#sentence2gene]}, $originalQueryString;
		            push @{$sentence2gene[$#sentence2gene]}, $word_positions[$i];
		            push @{$sentence2gene[$#sentence2gene]}, $bestScore;
		            push @{$sentence2gene[$#sentence2gene]}, $matchCode;            # score match code    
		            push @{$sentence2gene[$#sentence2gene]}, $methodCode;                     # overall SciMiner methodCode
		            push @{$sentence2gene[$#sentence2gene]}, get_flanking_text_for_symbol_match(\@sentence_split, $i, 10);
				}
			}
			
			
			#  -----------------------------------------------------------------
			#  STEP - 4 : Having '-'	
			#  -----------------------------------------------------------------
			#  03/30/2008 ------------------------------------------------------
			#  String with '-' will be truncated and tested
			elsif ($sentence_split[$i] =~ /\-/)
			{	my $originalQueryString		= $sentence_split[$i];
				my $tmpQueryString			= $originalQueryString;
				my $matchCode				= 11;
				
				#  Remove starting and ending dash
				if ($sentence_split[$i] =~ /^-/)
				{	$tmpQueryString			= $';
				}
				if ($sentence_split[$i] =~ /-$/)
				{	$tmpQueryString			= $`;
				}
				
				#  Check for -dependent, -related, -specific, -receptor, etc
				elsif ($sentence_split[$i] =~ /^(.*)-(like|dependent|specific|receptor|staining|induced|inducible|activated|repressed|stimulated|controlled|enhanced|mediated)$/i)
				{   my $base				= $1;
					my $ext					= lc($2);
					
					if ($isoformUpperHash{$ext} eq "")
					{	$tmpQueryString		= $base;
					}else
					{	# This specifically applies to '-receptor'
						# ex) INS-receptor => INS-R or INSR or at least INS
						$tmpQueryString		= $base.'-'.$isoformUpperHash{$ext};
						if (not defined $$UNIQSYM2IDHash{$tmpQueryString})
						{	# Try to convert to upper case
							if (not defined $$UNIQSYM2IDHash{uc($tmpQueryString)})
							{	# Try to remove the dash
								$tmpQueryString		= $base.$isoformUpperHash{$ext};
								if (not defined $$UNIQSYM2IDHash{$tmpQueryString})
								{	# Try to convert to upper case
									if (not defined $$UNIQSYM2IDHash{uc($tmpQueryString)})
									{	# Remove the last part
										$tmpQueryString		= $base;
									}
								}
							}
						}
					}
					
					#  Check for additional alpha,beta,gamma stuff
					if (not defined $$UNIQSYM2IDHash{$tmpQueryString})
					{	if ($tmpQueryString =~ /-(alpha|beta|gamma|kappa)$/i)
						{   my $tmpIsoform	= $1;
							$tmpQueryString =~ s/$tmpIsoform/$isoformUpperHash{lc($tmpIsoform)}/g;
							if (not defined $$UNIQSYM2IDHash{$tmpQueryString}) 
							{	#  Check for upper case
								if (not defined $$UNIQSYM2IDHash{uc($tmpQueryString)})
								{   $tmpQueryString	=~ s/\-//g;
									if (not defined $$UNIQSYM2IDHash{$tmpQueryString})
									{	$tmpQueryString	= uc($tmpQueryString);
									}
								}
							}
						}
						
						elsif (defined $$UNIQSYMHASHLOWKEY2HUGO{$tmpQueryString}) 
						{	#  Good, just proceed
						
						
						}else
						{	#  Check for lower characters
							if ($tmpQueryString =~ /[A-Z]/)
							{	if (defined $$wordListRef{lc($tmpQueryString)})
								{	#print "exclude defined here $sentence_split[$i]\n";
									next;
								}else
								{	$tmpQueryString = uc($tmpQueryString);
								}
							}else
							{   ## term for all in lower case, check the length
								#if (length($sentence_split[$i]) < 7)
								#{   next;
								#}
								if (defined $$wordListRef{$tmpQueryString})
								{	#print "exclude defined here $sentence_split[$i]\n";
									next;
								}else
								{   $tmpQueryString = uc($tmpQueryString);
								}
							}
						}
					}
				}else
				{   
					#  Check for plural case
					if ($sentence_split[$i] =~ /^(.*)s$/)
					{	my $tmpBase			= $1;
						# ignore when there is lower character in $tmpBase
						if ($tmpBase =~ /[a-z]/)
						{   # ignore
						}else
						{   if (defined $$UNIQSYM2IDHash{$tmpBase}) 
							{	$tmpQueryString	= $tmpBase;
							}
						}
					}
					
					if ($sentence_split[$i] =~ /^(alpha|beta|gamma)(\d+)-(\S+)$/i)
					{	# beta1-syntrophin	==> 	syntrophin beta 1
						my $tmpMergedString	= $3.' '.$1.' '.$2;
						
						if (defined $$UNIQNAME2IDHash{$tmpMergedString}) 
						{   #  This is actually a name matching, thus no need to run CoExist score calculation is necessary
						
							#  First, check if the score is pre-defined. If it's predifined then we don't need to worry about conflicting symbol
							my $bestHUGOID          = $$UNIQNAME2IDHash{$tmpMergedString};
							my $bestScore           = 1;
							$matchFound				= $tmpMergedString;
							   
							# Add the current finding to the final result array @sentence2gene
						    if (not defined $sentence2gene[0])
							{   $sentence2gene[0]->[0]  = $bestHUGOID;
							}else
							{   $sentence2gene[$#sentence2gene+1]->[0] = $bestHUGOID;
							}
						    push @{$sentence2gene[$#sentence2gene]}, $tmpMergedString;
						    push @{$sentence2gene[$#sentence2gene]}, $sentence_split[$i];
						    push @{$sentence2gene[$#sentence2gene]}, $word_positions[$i];
						    push @{$sentence2gene[$#sentence2gene]}, $bestScore;
						    push @{$sentence2gene[$#sentence2gene]}, $matchCode;            # score match code    
						    push @{$sentence2gene[$#sentence2gene]}, $methodCode;           # overall SciMiner methodCode
						    push @{$sentence2gene[$#sentence2gene]}, get_flanking_text_for_symbol_match(\@sentence_split, $i, 10);
						 	next;   
						}

						if (defined $$UNIQNAME2IDHash{$tmpMergedString}) 
						{	$tmpQueryString	= $tmpMergedString;
						}
					}
					
					if (not defined $$UNIQSYM2IDHash{$tmpQueryString}) 
					{	# Try to remove the '-' but this is very dangerous
						# Do not remove where number dash number format
						if ($tmpQueryString =~ /\d+-\d+$/)
						{   # Skip this format
							next;
						}else
						{	if ($tmpQueryString =~ /-(\S+?)$/)
							{	my $tmpBase	= $`;
								my $tmpExt	= $1;
								
								#  Check if the tmpBase has only lower chars, no number
								if ($tmpQueryString =~ /^(\D+)-(\d+)$/)
								{	# such as 'lin-7'
									my $tmpMergedString	= $1.$2;
									if (defined $$UNIQSYM2IDHash{$tmpMergedString})
									{	$tmpQueryString	= $tmpMergedString;
									}else
									{	if (defined $$UNIQSYM2IDHash{uc($tmpMergedString)})
										{	$tmpQueryString	= uc($tmpMergedString);
										}
									}
								}elsif ((check_upper_number_char($tmpBase)) && ($tmpExt !~ /\(|\)|\//))
								{   #  if the extension has more than 5 characters
									#  then, it's better to remove the ext.
									#  this might catch any control words not 
									#  included in the above isoform~~~
								
									#  Check for merged one first
									my $tmpMergedString = $tmpBase.$tmpExt;
									
									#  If the merged one only has upper characters then use it
									if ($tmpMergedString !~ /[a-z]/)
									{	if (defined $$UNIQSYM2IDHash{$tmpMergedString})
										{	$tmpQueryString	= $tmpMergedString;
										}
									}elsif (length($tmpExt) > 5)
									{	#  first check existing alpha/beta/gamma/kappa and then try to remove the extension
										if ($sentence_split[$i] =~ /(alpha|beta|gamma|kappa)/)
										{   #  Check whether this is at the beginning

											my $beforeLength	= length($`);
											my $tmpIsoform		= $1;
											my $tmpOriginal		= $sentence_split[$i];
											if ($beforeLength == 0)
											{	# these words are at the beginning of the term
												# don't do anything
												# $tmpQueryString = uc($tmpQueryString);
											}else
											{   $tmpOriginal =~ s/$tmpIsoform/$isoformUpperHash{$tmpIsoform}/g;
												if (not defined $$UNIQSYM2IDHash{$tmpOriginal}) 
												{	$tmpQueryString = uc($tmpOriginal);
													if (not defined $$UNIQSYM2IDHash{$tmpQueryString})
													{	$tmpQueryString		= $tmpQueryString;
														$tmpQueryString		=~ s/\-//g;
														if (not defined $$UNIQSYM2IDHash{$tmpQueryString})
														{	$tmpQueryString		= uc($tmpQueryString);
														}
													}
												}
											}
											
											#  Check for additional by removed dash
										}else
										{	$tmpQueryString	= $tmpBase;
											if ((not defined $$UNIQSYM2IDHash{$tmpBase}) && (not defined $$wordListRef{lc($tmpBase)}))
											{	if (defined $$UNIQSYM2IDHash{uc($tmpBase)}) 
												{	$tmpQueryString	= uc($tmpBase);
												}
											}
										}
									}else
									{   # if they are NOT longer than 5 char
										# only remove the last dash
										# When there is a number character in the extension
										# Or there is only one character
										if (($tmpExt =~ /\d/) || (length($tmpExt) == 1))
										{   $tmpQueryString	= $tmpBase.$tmpExt;
											if (not defined $$UNIQSYM2IDHash{$tmpQueryString}) 
											{	if ((defined $$UNIQSYM2IDHash{uc($tmpQueryString)}) && (not defined $$wordListRef{lc($tmpQueryString)}))
												{	$tmpQueryString	= uc($tmpQueryString);
												}
											}   
										}
									}
								}
							}
						}
						
						#  Check for multiple dashes
						if (not defined $$UNIQSYM2IDHash{$tmpQueryString}) 
						{	my $tmpString	= $sentence_split[$i];
							$tmpString		=~ s/^\-//g;
							$tmpString		=~ s/\-$//g;
							my @tmpArraySplit = split (/\-/, $tmpString);
							my $arrCount	= scalar @tmpArraySplit;
							
							if ($arrCount >= 3)
							{	# Try to merge all of them
								$tmpString	= join ("", @tmpArraySplit);
								if (not defined $$UNIQSYM2IDHash{$tmpString}) 
								{	$tmpQueryString	= uc($tmpString);
								}
							}
						}
					}
					
					##  Check for plural case
					#my $strCancidate		= '';
					#if ($sentence_split[$i] =~ /^(.*)s/)
					#{	my $tmpBase			= $1;
					#	# ignore when there is lower character in $tmpBase
					#	if ($tmpBase =~ /[a-z]/)
					#	{   # ignore
					#	}else
					#	{   if (defined $$UNIQSYM2IDHash{$tmpBase}) 
					#		{	$strCancidate	= $tmpBase;
					#		}
					#	}
					#}
					#
					#if (!$strCancidate)
					#{	$tmpQueryString	=~ s/\-//g;
					#}else
					#{	$tmpQueryString = $strCancidate;
					#}
				}
				
				if (not defined $$UNIQSYM2IDHash{$tmpQueryString}) 
			    {   #  Still there is a alpha/beta/gamma/kappa term
			    	if ($sentence_split[$i] =~ /(alpha|beta|gamma|kappa)/)
			    	{   #  Check whether this is at the beginning
			    		my $beforeLength	= length($`);
			    		my $tmpIsoform		= $1;
			    		my $tmpOriginal		= $sentence_split[$i];
			    		if ($beforeLength == 0)
			    		{	# these words are at the beginning of the term
			    			# don't do anything
			    			# $tmpQueryString = uc($tmpQueryString);
			    		}else
			    		{   $tmpOriginal =~ s/$tmpIsoform/$isoformUpperHash{$tmpIsoform}/g;
			    			if (not defined $$UNIQSYM2IDHash{$tmpOriginal}) 
							{	$tmpQueryString = uc($tmpOriginal);
								if (not defined $$UNIQSYM2IDHash{$tmpQueryString})
								{	$tmpQueryString		= $tmpQueryString;
									$tmpQueryString		=~ s/\-//g;
									if (not defined $$UNIQSYM2IDHash{$tmpQueryString})
									{	$tmpQueryString		= uc($tmpQueryString);
									}
								}
							}
			    		}
			    	}
			    	
			    	#else
			    	#{	#  Try to make everything upper case
			    	#	$tmpQueryString = uc($tmpQueryString);
			    	#}
			    }
			    
				if (defined $$UNIQSYM2IDHash{$tmpQueryString}) 
				{   if (length($tmpQueryString) < 3)
					{   next;
					}
					#  First, check if the score is pre-defined. If it's predifined then we don't need to worry about conflicting symbol
					my $bestHUGOID          = $$UNIQSYM2IDHash{$tmpQueryString};
					my $bestScore           = -1;
					$matchFound				= $tmpQueryString;
					   
					if (not defined $$coExistScoreRef{$tmpQueryString})
					{   #  If the coExistScore is not defined, then conflicting symbol must be checked.
					    if ( defined $$DUPSYM2HUGORef{lc($tmpQueryString)})
					    {   #  This will give you an array reference for hugo IDs assigned to this symbol
		                    #  Let's calculate the co-existence score of the hugo IDs in this array
		                    my @conflictHUGOIDs     = @{$$DUPSYM2HUGORef{lc($tmpQueryString)}};
		                    for (my $j=0; $j <= $#conflictHUGOIDs; $j++)
		                    {   if (not defined $$hugoID2scoreRef{$conflictHUGOIDs[$j]})
		                        {   $$hugoID2scoreRef{$conflictHUGOIDs[$j]}     = SciMiner_CoExist_Score_Calculate_With_Symbol(
		                        													$wholeTextContentLWRef, $wholeTextContentRef,
		                        													$tmpQueryString,
		                                                                            $$NonRedundantID2NameArray{$conflictHUGOIDs[$j]}, 
		                                                                            $$NonRedundantID2NameTypeArray{$conflictHUGOIDs[$j]},
																					$HUGO2AllSymbolRef, $conflictHUGOIDs[$j]) ;		# deduction of 0.5 for same symbol
		                        }

		                        #  Compare this score with the current maximum and update if necessary
		                        if ( $$hugoID2scoreRef{$conflictHUGOIDs[$j]} > $bestScore)
		                        {   $bestScore      = $$hugoID2scoreRef{$conflictHUGOIDs[$j]};
		                            $bestHUGOID     = $conflictHUGOIDs[$j];
		                        }                 
		                    }
					    }else
					    {   #  If there is no conflict, then just calculate the score
					        if (not defined $$hugoID2scoreRef{$bestHUGOID})
		                    {   $$hugoID2scoreRef{$bestHUGOID} = SciMiner_CoExist_Score_Calculate_With_Symbol(
		                    										$wholeTextContentLWRef,  $wholeTextContentRef,
		                    										$tmpQueryString,
		                                                            $$NonRedundantID2NameArray{$bestHUGOID}, 
		                                                            $$NonRedundantID2NameTypeArray{$bestHUGOID},
																	$HUGO2AllSymbolRef, $bestHUGOID);
		                    }
		                    $bestScore = $$hugoID2scoreRef{$bestHUGOID};
					    }
					    
					    #  We finally have a score and hugoID (if there was a conflict) for this specific symbol $tmpQueryString)
					    $$coExistScoreRef{$tmpQueryString}          = $bestScore;
					    $$coExistScoreMatchRef{$tmpQueryString}     = $matchCode;
					    $$coExistScoreHUGOIDRef{$tmpQueryString}    = $bestHUGOID;
					}else
					{   $bestScore  = $$coExistScoreRef{$tmpQueryString}; 
					    $matchCode  = $$coExistScoreMatchRef{$tmpQueryString}; 
					    $bestHUGOID = $$coExistScoreHUGOIDRef{$tmpQueryString}; 
					}

				

					#  Add the current finding to the final result array @sentence2gene
		            if (not defined $sentence2gene[0])
					{   $sentence2gene[0]->[0]  = $bestHUGOID;
					}else
					{   $sentence2gene[$#sentence2gene+1]->[0] = $bestHUGOID;
					}
		            push @{$sentence2gene[$#sentence2gene]}, $tmpQueryString;
		            push @{$sentence2gene[$#sentence2gene]}, $originalQueryString;
		            push @{$sentence2gene[$#sentence2gene]}, $word_positions[$i];
		            push @{$sentence2gene[$#sentence2gene]}, $bestScore;
		            push @{$sentence2gene[$#sentence2gene]}, $matchCode;            # score match code    
		            push @{$sentence2gene[$#sentence2gene]}, $methodCode;           # overall SciMiner methodCode
		            push @{$sentence2gene[$#sentence2gene]}, get_flanking_text_for_symbol_match(\@sentence_split, $i, 10);
		            
		            #REMOVEREMOVE
		            #LogQuery("matchcode 11 found $originalQueryString\t$tmpQueryString\t".get_flanking_text_for_symbol_match(\@sentence_split, $i, 10));
				}
			}
			
			
			#  -----------------------------------------------------------------
			#  STEP - 5 : ending with 'alpha, beta, gamma, kappa'
			#  -----------------------------------------------------------------
			#  03/30/2008 ------------------------------------------------------
			#  Something ending with 'alpha, beta, gamma, kappa'
			elsif ($sentence_split[$i] =~ /^(.*)(alpha|beta|gamma|kappa)$/)
			{	#  TNF-gamma	=> TNF-G	 or TNFG
				my $originalQueryString		= $sentence_split[$i];
				my $baseString				= $1;
				my $tmpIsoform				= $2;			    	
				my $tmpQueryString			= $baseString.$isoformUpperHash{$tmpIsoform};
				$matchCode					= 12;
			    
			    if (not defined $$UNIQSYM2IDHash{$tmpQueryString}) 
			    {   $tmpQueryString			= uc($tmpQueryString);
			    	if (not defined $$UNIQSYM2IDHash{$tmpQueryString}) 
			    	{   #  Introduce additional '-'
			    		$tmpQueryString	= $baseString.'-'.$tmpIsoform;
		    			if (not defined $$UNIQSYM2IDHash{$tmpQueryString}) 
		    			{	$tmpQueryString	= $baseString.'-'.uc($tmpIsoform);
		    				if (not defined $$UNIQSYM2IDHash{$tmpQueryString}) 
							{	$tmpQueryString	= $baseString.'-'.$isoformUpperHash{$tmpIsoform};
							}	
		    			}
			    	}
			    }
			    
				if (defined $$UNIQSYM2IDHash{$tmpQueryString}) 
				{   if (length($tmpQueryString) < 3)
					{   next;
					}
					#  First, check if the score is pre-defined. If it's predifined then we don't need to worry about conflicting symbol
					my $bestHUGOID          = $$UNIQSYM2IDHash{$tmpQueryString};
					my $bestScore           = -1;
					$matchFound				= $tmpQueryString;
					
					if (not defined $$coExistScoreRef{$tmpQueryString})
					{   #  If the coExistScore is not defined, then conflicting symbol must be checked.
					    if ( defined $$DUPSYM2HUGORef{lc($tmpQueryString)})
					    {   #  This will give you an array reference for hugo IDs assigned to this symbol
		                    #  Let's calculate the co-existence score of the hugo IDs in this array
		                    my @conflictHUGOIDs     = @{$$DUPSYM2HUGORef{lc($tmpQueryString)}};
		                    for (my $j=0; $j <= $#conflictHUGOIDs; $j++)
		                    {   if (not defined $$hugoID2scoreRef{$conflictHUGOIDs[$j]})
		                        {   $$hugoID2scoreRef{$conflictHUGOIDs[$j]}     = SciMiner_CoExist_Score_Calculate_With_Symbol(
		                        													$wholeTextContentLWRef, $wholeTextContentRef,
		                        													$tmpQueryString,
		                                                                            $$NonRedundantID2NameArray{$conflictHUGOIDs[$j]}, 
		                                                                            $$NonRedundantID2NameTypeArray{$conflictHUGOIDs[$j]},
																					$HUGO2AllSymbolRef, $conflictHUGOIDs[$j]);		# deduction of 0.5 for same symbol
		                        }

		                        #  Compare this score with the current maximum and update if necessary
		                        if ( $$hugoID2scoreRef{$conflictHUGOIDs[$j]} > $bestScore)
		                        {   $bestScore      = $$hugoID2scoreRef{$conflictHUGOIDs[$j]};
		                            $bestHUGOID     = $conflictHUGOIDs[$j];
		                        }                 
		                    }
					    }else
					    {   #  If there is no conflict, then just calculate the score
					        if (not defined $$hugoID2scoreRef{$bestHUGOID})
		                    {   $$hugoID2scoreRef{$bestHUGOID} = SciMiner_CoExist_Score_Calculate_With_Symbol(
		                    										$wholeTextContentLWRef, $wholeTextContentRef,
		                    										$tmpQueryString,
		                                                            $$NonRedundantID2NameArray{$bestHUGOID}, 
		                                                            $$NonRedundantID2NameTypeArray{$bestHUGOID},
																	$HUGO2AllSymbolRef, $bestHUGOID);
		                    }
		                    $bestScore = $$hugoID2scoreRef{$bestHUGOID};
					    }
					    
					    #  We finally have a score and hugoID (if there was a conflict) for this specific symbol $tmpQueryString)
					    $$coExistScoreRef{$tmpQueryString}          = $bestScore;
					    $$coExistScoreMatchRef{$tmpQueryString}     = $matchCode;
					    $$coExistScoreHUGOIDRef{$tmpQueryString}    = $bestHUGOID;
					}else
					{   $bestScore  = $$coExistScoreRef{$tmpQueryString}; 
					    $matchCode  = $$coExistScoreMatchRef{$tmpQueryString}; 
					    $bestHUGOID = $$coExistScoreHUGOIDRef{$tmpQueryString}; 
					}

				

					#  Add the current finding to the final result array @sentence2gene
		            if (not defined $sentence2gene[0])
					{   $sentence2gene[0]->[0]  = $bestHUGOID;
					}else
					{   $sentence2gene[$#sentence2gene+1]->[0] = $bestHUGOID;
					}
		            push @{$sentence2gene[$#sentence2gene]}, $tmpQueryString;
		            push @{$sentence2gene[$#sentence2gene]}, $originalQueryString;
		            push @{$sentence2gene[$#sentence2gene]}, $word_positions[$i];
		            push @{$sentence2gene[$#sentence2gene]}, $bestScore;
		            push @{$sentence2gene[$#sentence2gene]}, $matchCode;            # score match code    
		            push @{$sentence2gene[$#sentence2gene]}, $methodCode;                     # overall SciMiner methodCode
		            push @{$sentence2gene[$#sentence2gene]}, get_flanking_text_for_symbol_match(\@sentence_split, $i, 10);
				}
			}
			
			
			
	
			
			#  -----------------------------------------------------------------
			#  STEP - 6 : Check for plural gene groups
			#  -----------------------------------------------------------------
			#  03/30/2008 ------------------------------------------------------
			#  Check for plural gene groups
			elsif ($sentence_split[$i] =~ /^(.*)s$/)
			{	#  remove the first h|m and make the remaining to all upper case
			    #  ex) ATF6A 	-> score = 1      	==> ATF6alpha 	-> score = 1     
				$matchCode		= 13;
				my $baseString	= $1;
				if ($baseString =~ /^(protein|gene|mRNA)$/)
				{	#  continue for these cases
				}elsif ($baseString =~ /[a-z]/)
				{   next;
				}
				
				#  check for next $sentence_split[$i+1]
				my $tmpIndex		= $i;
				my @tmpStringArray	= ();
				
				#  Check for FA proteins A, C, G and F
				if ($baseString =~ /^(protein|gene|mRNA)$/)
				{   #  Merge only upper characters
					if ($sentence_split[$i-1] =~ /[a-z]/)
					{   next;
					}else
					{   my $tmpIndex = $i;
						while(defined $sentence_split[$tmpIndex+1]) 
						{	if ($sentence_split[$tmpIndex+1] eq "and")
							{	#  continue
							}else
							{   if (($sentence_split[$tmpIndex+1] =~ /[a-z]/) ||
									(length($sentence_split[$tmpIndex+1]) > 1))
								{   last;
								}
							
								my $tmpLocalString	= $sentence_split[$i-1].$sentence_split[$tmpIndex+1];
								if (not defined $$UNIQSYM2IDHash{$tmpLocalString})
								{   $tmpLocalString	= $sentence_split[$i-1].'-'.$sentence_split[$tmpIndex+1];
									if (defined $$UNIQSYM2IDHash{$tmpLocalString})
									{   push @tmpStringArray, $tmpLocalString;
									}
								}else
								{   push @tmpStringArray, $tmpLocalString;
								}
							}
							$tmpIndex++;
						}
					}
				}
				

				if (defined $$UNIQSYM2IDHash{$baseString})
				{	push @tmpStringArray, $baseString;
				}

				
				while()
				{   $tmpIndex++;
					if (not defined $sentence_split[$tmpIndex])
					{   last;
					}
					
					if ($sentence_split[$tmpIndex] =~ /^and$/i)
					{   next;
					}
				
					if ($sentence_split[$tmpIndex] !~ /\D/)
					{	my $tmpString 	= $baseString.$sentence_split[$tmpIndex];
						if (defined $$UNIQSYM2IDHash{$tmpString}) 
						{   push @tmpStringArray, $tmpString;  
						}else
						{   last;
						}
					}else
					{   last;
					}
				}	
				
				if (not defined $tmpStringArray[0])
				{   next;
				}

				my $originalQueryString		= $sentence_split[$i];
				foreach my $tmpQueryString (@tmpStringArray)
				{	if (length($tmpQueryString) < 3)
					{   next;
					}
					if (defined $$UNIQSYM2IDHash{$tmpQueryString}) 
					{   #  First, check if the score is pre-defined. If it's predifined then we don't need to worry about conflicting symbol
						my $bestHUGOID          = $$UNIQSYM2IDHash{$tmpQueryString};
						my $bestScore           = -1;
						$matchFound				= $tmpQueryString;
						
						if (not defined $$coExistScoreRef{$tmpQueryString})
						{   #  If the coExistScore is not defined, then conflicting symbol must be checked.
							if ( defined $$DUPSYM2HUGORef{lc($tmpQueryString)})
							{   #  This will give you an array reference for hugo IDs assigned to this symbol
				                #  Let's calculate the co-existence score of the hugo IDs in this array
				                my @conflictHUGOIDs     = @{$$DUPSYM2HUGORef{lc($tmpQueryString)}};
				                for (my $j=0; $j <= $#conflictHUGOIDs; $j++)
				                {   if (not defined $$hugoID2scoreRef{$conflictHUGOIDs[$j]})
				                    {   $$hugoID2scoreRef{$conflictHUGOIDs[$j]}     = SciMiner_CoExist_Score_Calculate_With_Symbol(
				                    													$wholeTextContentLWRef, $wholeTextContentRef,
				                    													$tmpQueryString,
				                                                                        $$NonRedundantID2NameArray{$conflictHUGOIDs[$j]}, 
				                                                                        $$NonRedundantID2NameTypeArray{$conflictHUGOIDs[$j]},
																						$HUGO2AllSymbolRef, $conflictHUGOIDs[$j]);		# deduction of 0.5 for same symbol
				                    }

				                    #  Compare this score with the current maximum and update if necessary
				                    if ( $$hugoID2scoreRef{$conflictHUGOIDs[$j]} > $bestScore)
				                    {   $bestScore      = $$hugoID2scoreRef{$conflictHUGOIDs[$j]};
				                        $bestHUGOID     = $conflictHUGOIDs[$j];
				                    }                 
				                }
							}else
							{   #  If there is no conflict, then just calculate the score
							    if (not defined $$hugoID2scoreRef{$bestHUGOID})
				                {   $$hugoID2scoreRef{$bestHUGOID} = SciMiner_CoExist_Score_Calculate_With_Symbol(
				                										$wholeTextContentLWRef, $wholeTextContentRef,
				                										$tmpQueryString,
				                                                        $$NonRedundantID2NameArray{$bestHUGOID}, 
				                                                        $$NonRedundantID2NameTypeArray{$bestHUGOID},
																		$HUGO2AllSymbolRef, $bestHUGOID);
				                }
				                $bestScore = $$hugoID2scoreRef{$bestHUGOID};
							}
							
							#  We finally have a score and hugoID (if there was a conflict) for this specific symbol $tmpQueryString)
							$$coExistScoreRef{$tmpQueryString}          = $bestScore;
							$$coExistScoreMatchRef{$tmpQueryString}     = $matchCode;
							$$coExistScoreHUGOIDRef{$tmpQueryString}    = $bestHUGOID;
						}else
						{   $bestScore  = $$coExistScoreRef{$tmpQueryString}; 
							$matchCode  = $$coExistScoreMatchRef{$tmpQueryString}; 
							$bestHUGOID = $$coExistScoreHUGOIDRef{$tmpQueryString}; 
						}

				

						#  Add the current finding to the final result array @sentence2gene
				        if (not defined $sentence2gene[0])
						{   $sentence2gene[0]->[0]  = $bestHUGOID;
						}else
						{   $sentence2gene[$#sentence2gene+1]->[0] = $bestHUGOID;
						}
				        push @{$sentence2gene[$#sentence2gene]}, $tmpQueryString;
				        push @{$sentence2gene[$#sentence2gene]}, $originalQueryString;
				        push @{$sentence2gene[$#sentence2gene]}, $word_positions[$i];
				        push @{$sentence2gene[$#sentence2gene]}, $bestScore;
				        push @{$sentence2gene[$#sentence2gene]}, $matchCode;            # score match code    
				        push @{$sentence2gene[$#sentence2gene]}, $methodCode;                     # overall SciMiner methodCode
				        push @{$sentence2gene[$#sentence2gene]}, get_flanking_text_for_symbol_match(\@sentence_split, $i, 10);
					}
				}			
			}
			
			
			#  03/30/2008 ------------------------------------------------------
			#  Try convert to uppder case
			elsif ($sentence_split[$i] =~ /[a-z]/)
			{	
				# REMOVEREMOVE
				# NEED TO WORK ON HERE 
				$matchCode		= 14;
		
				#  If the term is all in lower case and included as engdictionary
				if ($sentence_split[$i] =~ /[A-Z]/)
				{	if (defined $$wordListRef{lc($sentence_split[$i])})
					{	#print "exclude defined here $sentence_split[$i]\n";
						next;
					}
				}else
				{   ## term for all in lower case, check the length
					#if (length($sentence_split[$i]) < 7)
					#{   next;
					#}
					if (defined $$wordListRef{$sentence_split[$i]})
					{	#print "exclude defined here $sentence_split[$i]\n";
						next;
					}else
					{   
					}
				}
				
				my $originalQueryString		= $sentence_split[$i];
				my $tmpQueryString			= uc($originalQueryString);
			    
				if (defined $$UNIQSYM2IDHash{$tmpQueryString}) 
				{   #  First, check if the score is pre-defined. If it's predifined then we don't need to worry about conflicting symbol
					my $bestHUGOID          = $$UNIQSYM2IDHash{$tmpQueryString};
					my $bestScore           = -1;
					$matchFound				= $tmpQueryString;
					
					if (not defined $$coExistScoreRef{$tmpQueryString})
					{   #  If the coExistScore is not defined, then conflicting symbol must be checked.
					    if ( defined $$DUPSYM2HUGORef{lc($tmpQueryString)})
					    {   #  This will give you an array reference for hugo IDs assigned to this symbol
		                    #  Let's calculate the co-existence score of the hugo IDs in this array
		                    my @conflictHUGOIDs     = @{$$DUPSYM2HUGORef{lc($tmpQueryString)}};
		                    for (my $j=0; $j <= $#conflictHUGOIDs; $j++)
		                    {   if (not defined $$hugoID2scoreRef{$conflictHUGOIDs[$j]})
		                        {   $$hugoID2scoreRef{$conflictHUGOIDs[$j]}     = SciMiner_CoExist_Score_Calculate_With_Symbol(
		                        													$wholeTextContentLWRef, $wholeTextContentRef,
		                        													$tmpQueryString,
		                                                                            $$NonRedundantID2NameArray{$conflictHUGOIDs[$j]}, 
		                                                                            $$NonRedundantID2NameTypeArray{$conflictHUGOIDs[$j]},
																					$HUGO2AllSymbolRef, $conflictHUGOIDs[$j]);		# deduction of 0.5 for same symbol
		                        }

		                        #  Compare this score with the current maximum and update if necessary
		                        if ( $$hugoID2scoreRef{$conflictHUGOIDs[$j]} > $bestScore)
		                        {   $bestScore      = $$hugoID2scoreRef{$conflictHUGOIDs[$j]};
		                            $bestHUGOID     = $conflictHUGOIDs[$j];
		                        }                 
		                    }
					    }else
					    {   #  If there is no conflict, then just calculate the score
					        if (not defined $$hugoID2scoreRef{$bestHUGOID})
		                    {   $$hugoID2scoreRef{$bestHUGOID} = SciMiner_CoExist_Score_Calculate_With_Symbol(
		                    										$wholeTextContentLWRef, $wholeTextContentRef,
		                    										$tmpQueryString,
		                                                            $$NonRedundantID2NameArray{$bestHUGOID}, 
		                                                            $$NonRedundantID2NameTypeArray{$bestHUGOID},
																	$HUGO2AllSymbolRef, $bestHUGOID);
		                    }
		                    $bestScore = $$hugoID2scoreRef{$bestHUGOID};
					    }
					    
					    #  We finally have a score and hugoID (if there was a conflict) for this specific symbol $tmpQueryString)
					    $$coExistScoreRef{$tmpQueryString}          = $bestScore;
					    $$coExistScoreMatchRef{$tmpQueryString}     = $matchCode;
					    $$coExistScoreHUGOIDRef{$tmpQueryString}    = $bestHUGOID;
					}else
					{   $bestScore  = $$coExistScoreRef{$tmpQueryString}; 
					    $matchCode  = $$coExistScoreMatchRef{$tmpQueryString}; 
					    $bestHUGOID = $$coExistScoreHUGOIDRef{$tmpQueryString}; 
					}

				

					#  Add the current finding to the final result array @sentence2gene
		            if (not defined $sentence2gene[0])
					{   $sentence2gene[0]->[0]  = $bestHUGOID;
					}else
					{   $sentence2gene[$#sentence2gene+1]->[0] = $bestHUGOID;
					}
		            push @{$sentence2gene[$#sentence2gene]}, $tmpQueryString;
		            push @{$sentence2gene[$#sentence2gene]}, $originalQueryString;
		            push @{$sentence2gene[$#sentence2gene]}, $word_positions[$i];
		            push @{$sentence2gene[$#sentence2gene]}, $bestScore;
		            push @{$sentence2gene[$#sentence2gene]}, $matchCode;            # score match code    
		            push @{$sentence2gene[$#sentence2gene]}, $methodCode;                     # overall SciMiner methodCode
		            push @{$sentence2gene[$#sentence2gene]}, get_flanking_text_for_symbol_match(\@sentence_split, $i, 10);
				}
			}
			
			
			#			#  Check for further grouping
			if (($matchFound) && (defined $sentence_split[$i+1]) && ($sentence_split[$i+1] =~ /^(and|to)$/))
			{   my $sameFormat		= 0;
				my $extensionMode	= $1;
				my $firstNumber		= 0;
				my $lastNumber		= 0;
				my $secondBase		= '';
					
				$matchCode		= 15;
					
				#  First get the base string
				my $firstPart		= '';
				my $basePart		= '';
				my $secondPart		= '';
				if ($matchFound =~ /^(\S+)(\d+)$/)
				{	$firstPart	= $1;
					$secondPart	= $2;
					if (substr($firstPart, -1, 1) eq '-')
					{   $basePart	= $firstPart;
						substr($basePart, -1, 1) = '';
					}else
					{   $basePart	= $firstPart;
					}
				}else
				{   next;
				}
				
				#  Check for the next 
				if (not defined $sentence_split[$i+2])
				{   next;
				}else
				{   #  If it has only number
					if ($sentence_split[$i+2] =~ /^(\d+)$/)
					{	$lastNumber	= $1;
						$secondBase	= '';
					}
					
					#  elsif it has -number
					elsif ($sentence_split[$i+2] =~ /^(.*)(\d+)$/)
					{	my $tmpFirst	= $1;
						my $tmpBase		= '';
						$lastNumber		= $2;
						
						if ($tmpFirst eq '-')
						{   # This is acceptable
							$secondBase	= '';
						}else
						{   #  Base parts for two symbols must be same
							if (uc($tmpFirst) ne uc($firstPart))
							{   next;
							}
						}
					}
					
					#  Ignore any other types
					else
					{   next;
					}
				}

				
				#  Make new combinations
				my @tmpStringArray	= ();
				#  Enumerate the possible groups of proteins
				if ($extensionMode eq 'and')
				{   #  This is only for the single case
					my $tmpString	= $firstPart.$lastNumber;
					if (defined $$UNIQSYM2IDHash{$tmpString})
					{   push @tmpStringArray, $tmpString;
					}else
					{   #  Check upper case first
						my $tmpString2	= uc($tmpString);
						if (defined $$UNIQSYM2IDHash{$tmpString2})
						{   push @tmpStringArray, $tmpString2;
						}else
						{	if (substr($firstPart, -1, 1) eq '-')
							{	$tmpString	= $basePart.$lastNumber;
								if (defined $$UNIQSYM2IDHash{$tmpString})
								{   push @tmpStringArray, $tmpString;
								}else
								{	$tmpString2	= uc($tmpString);
									if (defined $$UNIQSYM2IDHash{$tmpString2})
									{   push @tmpStringArray, $tmpString2;
									}
								}
							}
						}
					}
				}else
				{	#  This extension mode is 'to'
					if ($secondPart >= $lastNumber)
					{   next;
					}
					
					for (my $snum=($secondPart+1); $snum<=$lastNumber; $snum++)
					{	my $tmpString	= $firstPart.$snum;
						if (defined $$UNIQSYM2IDHash{$tmpString})
						{   push @tmpStringArray, $tmpString;
						}else
						{   #  Check upper case first
							my $tmpString2	= uc($tmpString);
							if (defined $$UNIQSYM2IDHash{$tmpString2})
							{   push @tmpStringArray, $tmpString2;
							}else
							{	if (substr($firstPart, -1, 1) eq '-')
								{	$tmpString	= $basePart.$snum;
									if (defined $$UNIQSYM2IDHash{$tmpString})
									{   push @tmpStringArray, $tmpString;
									}else
									{	$tmpString2	= uc($tmpString);
										if (defined $$UNIQSYM2IDHash{$tmpString2})
										{   push @tmpStringArray, $tmpString2;
										}
									}
								}
							}
						}
					}
				}
				
				#  check for any string found
				if (not defined $tmpStringArray[0])
				{   next;
				}
			
				my $originalQueryString		= $sentence_split[$i];
				foreach my $tmpQueryString (@tmpStringArray)
				{	if (defined $$UNIQSYM2IDHash{$tmpQueryString}) 
					{   #  First, check if the score is pre-defined. If it's predifined then we don't need to worry about conflicting symbol
						my $bestHUGOID          = $$UNIQSYM2IDHash{$tmpQueryString};
						my $bestScore           = -1;
						$matchFound				= $tmpQueryString;
					
						if (not defined $$coExistScoreRef{$tmpQueryString})
						{   #  If the coExistScore is not defined, then conflicting symbol must be checked.
							if ( defined $$DUPSYM2HUGORef{lc($tmpQueryString)})
							{   #  This will give you an array reference for hugo IDs assigned to this symbol
					            #  Let's calculate the co-existence score of the hugo IDs in this array
					            my @conflictHUGOIDs     = @{$$DUPSYM2HUGORef{lc($tmpQueryString)}};
					            for (my $j=0; $j <= $#conflictHUGOIDs; $j++)
					            {   if (not defined $$hugoID2scoreRef{$conflictHUGOIDs[$j]})
					                {   $$hugoID2scoreRef{$conflictHUGOIDs[$j]}     = SciMiner_CoExist_Score_Calculate_With_Symbol(
					                													$wholeTextContentLWRef, $wholeTextContentRef,
					                													$tmpQueryString,
					                                                                    $$NonRedundantID2NameArray{$conflictHUGOIDs[$j]}, 
					                                                                    $$NonRedundantID2NameTypeArray{$conflictHUGOIDs[$j]},
																						$HUGO2AllSymbolRef, $conflictHUGOIDs[$j]);		# deduction of 0.5 for same symbol
					                }

					                #  Compare this score with the current maximum and update if necessary
					                if ( $$hugoID2scoreRef{$conflictHUGOIDs[$j]} > $bestScore)
					                {   $bestScore      = $$hugoID2scoreRef{$conflictHUGOIDs[$j]};
					                    $bestHUGOID     = $conflictHUGOIDs[$j];
					                }                 
					            }
							}else
							{   #  If there is no conflict, then just calculate the score
								if (not defined $$hugoID2scoreRef{$bestHUGOID})
					            {   $$hugoID2scoreRef{$bestHUGOID} = SciMiner_CoExist_Score_Calculate_With_Symbol(
					            										$wholeTextContentLWRef, $wholeTextContentRef,
					            										$tmpQueryString,
					                                                    $$NonRedundantID2NameArray{$bestHUGOID}, 
					                                                    $$NonRedundantID2NameTypeArray{$bestHUGOID},
																		$HUGO2AllSymbolRef, $bestHUGOID);
					            }
					            $bestScore = $$hugoID2scoreRef{$bestHUGOID};
							}
						
							#  We finally have a score and hugoID (if there was a conflict) for this specific symbol $tmpQueryString)
							$$coExistScoreRef{$tmpQueryString}          = $bestScore;
							$$coExistScoreMatchRef{$tmpQueryString}     = $matchCode;
							$$coExistScoreHUGOIDRef{$tmpQueryString}    = $bestHUGOID;
						}else
						{   $bestScore  = $$coExistScoreRef{$tmpQueryString}; 
							$matchCode  = $$coExistScoreMatchRef{$tmpQueryString}; 
							$bestHUGOID = $$coExistScoreHUGOIDRef{$tmpQueryString}; 
						}

			

						#  Add the current finding to the final result array @sentence2gene
					    if (not defined $sentence2gene[0])
						{   $sentence2gene[0]->[0]  = $bestHUGOID;
						}else
						{   $sentence2gene[$#sentence2gene+1]->[0] = $bestHUGOID;
						}
					    push @{$sentence2gene[$#sentence2gene]}, $tmpQueryString;
					    push @{$sentence2gene[$#sentence2gene]}, $tmpQueryString;
					    push @{$sentence2gene[$#sentence2gene]}, $word_positions[$i];
					    push @{$sentence2gene[$#sentence2gene]}, $bestScore;
					    push @{$sentence2gene[$#sentence2gene]}, $matchCode;            # score match code    
					    push @{$sentence2gene[$#sentence2gene]}, $methodCode;                     # overall SciMiner methodCode
					    push @{$sentence2gene[$#sentence2gene]}, get_flanking_text_for_symbol_match(\@sentence_split, $i, 10);
					}
				}
			}
			
			
		}else
		{   # If empty, just skip
		}
	}
	
	# !_! The following section has been deleted on 10/30/2008
	##  Add the term frequency for the current sentence
	#foreach my $lcConfTerm (keys %conflictFound)
	#{   #  Add $matchTermSentenceCountRef -- number of sentences with this conflicting symbol
	#    if (not defined $$matchTermSentenceCountRef{$lcConfTerm})
	#    {   $$matchTermSentenceCountRef{$lcConfTerm} = 1;       # first sentence
	#    }else
	#    {   $$matchTermSentenceCountRef{$lcConfTerm}++;
	#    }
	#
	#    if (not defined $$matchTerm2TermFreqRef{$lcConfTerm})
	#    {   my %term2countHash  = ();
	#        for (my $j=0; $j <= $#lowered_split_space; $j++)
	#        {   $term2countHash{$lowered_split_space[$j]}   = 1;
	#        }
	#        $$matchTerm2TermFreqRef{$lcConfTerm} = \%term2countHash;
	#    }else
	#    {   my $tmpHashRef  = $$matchTerm2TermFreqRef{$lcConfTerm};
	#        for (my $j=0; $j <= $#lowered_split_space; $j++)
	#        {   if (defined $$tmpHashRef{$lowered_split_space[$j]})
	#            {   $$tmpHashRef{$lowered_split_space[$j]}++;
	#            }else
	#            {   $$tmpHashRef{$lowered_split_space[$j]}=1;
	#            }
	#        }
	#    }
	#}
	#
    ##  Add the term frequency for the for whole document level
    #for (my $j=0; $j <= $#lowered_split_space; $j++)
    #{   if (defined $$docTermFreqRef{$lowered_split_space[$j]})
    #    {   $$docTermFreqRef{$lowered_split_space[$j]}++;
    #    }else
    #    {   $$docTermFreqRef{$lowered_split_space[$j]}=1;
    #    }
    #}
    
	return (\@sentence2gene);
}










# ----------------------------------------------------------------------------
# sub name_resolving_generif_based
# ----------------------------------------------------------------------------
# Last modified : 01/30/2008
# Description   : This subroutin applies the name resolving strategy
#                 based on the geneRif term frequency
# Original idea is from Dr. David States
# ----------------------------------------------------------------------------
sub name_resolving_generif_based
{   my ($confsymbol2senIDRef,
		$senID2sentenceRef,
		$matchTerm2TermFreq,
		$matchTermSentenceCountRef,
		$docTermFreqRef,
		$dupsym2hugoRef,
		$conflictingSymbol,
		$ID2GeneIDHashRef,
		$dbh,
		$lcHUGOSymbol2NCBIGeneIDRef,
		$entrezGeneID2geneRifSentenceRef,
		$entrezGeneID2geneRifTermFreqRef,
		$entrezGeneID2geneRifTermTotalCountRef,
		$word2excludeRef,
		$ID2SymbolHashRef) = @_;
    

    #  Collect the conflicting NCBI Gene ID for the given conflictingSymbol
    my %conflictingHUGOID2Score = ();
    my @conflictingNCBIGeneID   = ();
    my $conflictCount           = scalar @{$$dupsym2hugoRef{$conflictingSymbol}};
    my $resolveCode             = 0;
    my $resolveText             = "TotalCon:$conflictCount<>";
    my $geneRifCalcCount        = 0; 
    my @targetHUGOIDs           = ();       # To be calculated   
	my $docTermFreqTotalCount	= 0;    


    foreach my $hugoID (@{$$dupsym2hugoRef{$conflictingSymbol}})
    {   $conflictingHUGOID2Score{$hugoID}   = -1;       # set the default score
        if (not defined $$ID2GeneIDHashRef{$hugoID})
        {   $resolveText        .= "$hugoID|$$ID2SymbolHashRef{$hugoID}||No_NCBI__";
        }else
        {   if (not defined $$entrezGeneID2geneRifSentenceRef{$$ID2GeneIDHashRef{$hugoID}})
            {   $resolveText    .= "$hugoID|$$ID2SymbolHashRef{$hugoID}|$$ID2GeneIDHashRef{$hugoID}|No_GeneRif__";
            }else
            {   $geneRifCalcCount++;
				$resolveText    .= "$hugoID|$$ID2SymbolHashRef{$hugoID}|$$ID2GeneIDHashRef{$hugoID}|Complete__";
                push @targetHUGOIDs, $hugoID;
            }
        }
		
		if (not defined $$ID2SymbolHashRef{$hugoID})
		{	LogQuery("$hugoID $$ID2SymbolHashRef{$hugoID} is not defined...");			
		}
    }
    
	
    #  Check for the total number of available geneRifCalCount
    if ($geneRifCalcCount < 2)
    {   #  Only one ore less geneRif is available. No meaning to do-name_resolving
        $resolveCode             = 1;
        $resolveText            .= "<>AvaiableGeneRif=$geneRifCalcCount<>";
        return ($resolveCode, "", $resolveText);
    }else
    {   $resolveText            .= "<>AvaiableGeneRif=$geneRifCalcCount<>";
    }
    

	# --------------------------------------------------------------------------    
    #  Now, perform the name_resolving process for @targetHUGOIDs
    my %HUGOID2NameResolverScore       = ();
	
	my $tmpCount = scalar @targetHUGOIDs;
	
    foreach my $hugoID (@targetHUGOIDs)
    {	my $NCBIGeneID  = $$ID2GeneIDHashRef{$hugoID};
        my $tmpScore    = 0;
 
        #  Check for geneRifTermFreq. If not calculate now
        if (not defined $$entrezGeneID2geneRifTermFreqRef{$NCBIGeneID})
        {   #  Calculate the term frequency of the geneRif for given $NCBIGeneID    
            calculate_term_frequency ($NCBIGeneID, $entrezGeneID2geneRifSentenceRef, 
                                      $entrezGeneID2geneRifTermFreqRef, $word2excludeRef, $entrezGeneID2geneRifTermTotalCountRef);
        }

        #  ---------------------------------------------------------------------
        #  Calculate similarity score (name_resolver_score)
        #  If there at least 5 sentences in this document with this match string,
        #  then use the term list specific to these sentences for ranking.  
        #  Otherwise, use the document as a whole.
    
        my $geneRifFreqRef  = $$entrezGeneID2geneRifTermFreqRef{$NCBIGeneID};
        if ($$matchTermSentenceCountRef{$conflictingSymbol} < 5)
        {	#  Calculate total count of the terms if not pre-defined
			if ($docTermFreqTotalCount == 0)
			{	foreach my $term (keys %{$docTermFreqRef})
				{	$docTermFreqTotalCount += $$docTermFreqRef{$term};
				}
			}
			
			my @terms               = keys %{$geneRifFreqRef};
			foreach my $term (@terms)
            {	if (defined $$docTermFreqRef{$term})
                {   $tmpScore += $$geneRifFreqRef{$term} * $$docTermFreqRef{$term};
                }
            }
			
			# Adjust score by substracting the occurrence of the symbol itself.
			if ((defined $$geneRifFreqRef{$conflictingSymbol}) && (defined $$docTermFreqRef{$conflictingSymbol}))
			{   $tmpScore -= $$geneRifFreqRef{$conflictingSymbol} * $$docTermFreqRef{$conflictingSymbol};
			}			
            $HUGOID2NameResolverScore{$hugoID}  = $tmpScore / ($$entrezGeneID2geneRifTermTotalCountRef{$NCBIGeneID} * $docTermFreqTotalCount);
        }else
        {	my $matchTermFreqRef    = $$matchTerm2TermFreq{$conflictingSymbol};
			my @terms               = keys %{$matchTermFreqRef};
			my $matchTermTotalCount	= 0;
			foreach my $term (@terms)
            {	$matchTermTotalCount += $$matchTermFreqRef{$term};
				if (defined $$geneRifFreqRef{$term})
                {   $tmpScore += $$geneRifFreqRef{$term} * $$matchTermFreqRef{$term};
                }
            }
			if ((defined $$geneRifFreqRef{$conflictingSymbol}) && (defined $$matchTermFreqRef{$conflictingSymbol}))
			{   $tmpScore -= $$geneRifFreqRef{$conflictingSymbol} * $$matchTermFreqRef{$conflictingSymbol};
			}
            $HUGOID2NameResolverScore{$hugoID}  = $tmpScore / ($matchTermTotalCount * $$entrezGeneID2geneRifTermTotalCountRef{$NCBIGeneID}) ;
        }
    }    
    
    
    #  -------------------------------------------------------------------------
    #  Summarize the result
    my $bestScoreHUGOID     = '';
    my $bestScore           = 0;
    my $detailScoreText     = 'ScoreDetail__';
    
    foreach my $hugoID (keys %HUGOID2NameResolverScore)
    {   if ($HUGOID2NameResolverScore{$hugoID} >= $bestScore)
        {   $bestScoreHUGOID    = $hugoID;
            $bestScore          = $HUGOID2NameResolverScore{$hugoID};
        }
        $detailScoreText    .= "$hugoID|$$ID2SymbolHashRef{$hugoID}|$HUGOID2NameResolverScore{$hugoID}__";
    }

    #  Determine the resolveCode and resolveText    
    if ($bestScore > 0)
    {   $resolveCode        = 2;
    }else
    {   $resolveCode        = 3;
    }

    $resolveText            .= "BEST:$bestScoreHUGOID|$$ID2SymbolHashRef{$bestScoreHUGOID}|$bestScore<>".$detailScoreText;
    
    return ($resolveCode, $bestScoreHUGOID, $resolveText);
}                 










sub calculate_term_frequency
{   my ($NCBIGeneID, 
        $entrezGeneID2geneRifSentenceRef, 
        $entrezGeneID2geneRifTermFreqRef,
        $word2excludeRef,
		$entrezGeneID2geneRifTermTotalCountRef	) = @_;
                                      
                                      
    #  Process the sentences
	
    my @allSentences   	= @{$$entrezGeneID2geneRifSentenceRef{$NCBIGeneID}};
	my $tmpTermCount	= 0;
    foreach my $sentence (@allSentences)
    {   my $processedTxt    = braket_character_replaced_by_space (lc($sentence));
        $processedTxt       =~ s/\s+/ /g;
        my @splitBySpace    = split (/ /, $processedTxt);
        
        for (my $i=0; $i <= $#splitBySpace; $i++)
        {   if (defined $$word2excludeRef{$splitBySpace[$i]})
            {   next;
            }
            
            #  Remove the last period.
            $splitBySpace[$i] =~ s/\.$//g;
			$tmpTermCount++;
            if (not defined $$entrezGeneID2geneRifTermFreqRef{$NCBIGeneID})
            {   my %term2countHash                              = ();
                $term2countHash{$splitBySpace[$i]}              = 1;
                $$entrezGeneID2geneRifTermFreqRef{$NCBIGeneID}  = \%term2countHash;           
            }else
            {   if (not defined $$entrezGeneID2geneRifTermFreqRef{$NCBIGeneID}->{$splitBySpace[$i]})
                {   $$entrezGeneID2geneRifTermFreqRef{$NCBIGeneID}->{$splitBySpace[$i]} = 1;
                }else
                {   $$entrezGeneID2geneRifTermFreqRef{$NCBIGeneID}->{$splitBySpace[$i]}++;
                }
            }
        }
    }
	$$entrezGeneID2geneRifTermTotalCountRef{$NCBIGeneID}	= $tmpTermCount;
} 			    


sub define_word_to_exclude_for_frequency
{   my $word2exclude        = shift;

    $$word2exclude{'and'}   = 1;
    $$word2exclude{'or'}    = 1;
    $$word2exclude{'nor'}   = 1;
    $$word2exclude{'but'}   = 1;
    $$word2exclude{'as'}    = 1;
    $$word2exclude{'so'}    = 1;
    $$word2exclude{'to'}    = 1;
    $$word2exclude{'in'}    = 1;
    $$word2exclude{'into'}  = 1;
    $$word2exclude{'out'}   = 1;
    $$word2exclude{'for'}   = 1;
    $$word2exclude{'on'}    = 1;
    $$word2exclude{'by'}    = 1;
    $$word2exclude{'at'}    = 1;
    $$word2exclude{'of'}    = 1;
    $$word2exclude{'from'}  = 1;
    $$word2exclude{'with'}  = 1;
    $$word2exclude{'an'}    = 1;
    $$word2exclude{'a'}     = 1;
    $$word2exclude{'the'}   = 1;
    $$word2exclude{'such'}  = 1;
    $$word2exclude{'so'}    = 1;
    $$word2exclude{'now'}   = 1;
    $$word2exclude{'far'}   = 1;
    $$word2exclude{'is'}    = 1;
    $$word2exclude{'are'}   = 1;
    $$word2exclude{'were'}  = 1;
    $$word2exclude{'am'}    = 1;
    $$word2exclude{'an'}    = 1;
    $$word2exclude{'has'}   = 1;
    $$word2exclude{'have'}  = 1;
    $$word2exclude{'been'}  = 1;
    $$word2exclude{'be'}    = 1;
    $$word2exclude{'not'}   = 1;
    $$word2exclude{'that'}  = 1;
    $$word2exclude{'which'} = 1;
    $$word2exclude{'who'}   = 1;
    $$word2exclude{'where'} = 1;
    $$word2exclude{'how'}   = 1;
    $$word2exclude{'when'}  = 1;
    $$word2exclude{'why'}   = 1;
}
























#  ---------------------------------------------------------------------------
#  ---------------------------------------------------------------------------
#  Section II.  Name (Full length description) Parsing Part
#  ---------------------------------------------------------------------------
#  ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# sub SciMinerDB_Name_Parsing
# ---------------------------------------------------------------------------
# Last modified: 01/30/2008
# Description: This subroutin parses out gene names with flanking
#               text surrounding mined names from full text content.
# Return: No return
# ---------------------------------------------------------------------------
sub SciMinerDB_Name_Parsing
{   my ($annoENVRef, 
        $sourceDir, 
        $targetDir,
        $ID2SciMinerGeneID,
		$ID2SymbolHash, 
		$ID2NameHash,
		$UNIQNAMEArray, 
		$UNIQNAME2IDHash,
		$UNIQNAME2ORIGINAL, 
		$first4codeStart,
		$first4codeEnd,
        $programName, 
        $dbh,
        $PhenotypeOnlyToBeExcludedHUGOID, 
        $pmid2docIDRef,
        $partNameHashRef,
		$dbUpdateOption,
		$EXCLUDESYMBOLCOND,
		$InputFileMode,
		$wordListRef						)= @_; 
        

    #  Set Column String to be inserted.
    my $colNameString = "pmid, senID, geneID, hgncID, approvedSymbol, matchString, actualString, startPos, score, flankingText, matchCodeID, tag, SciMinerVersion, SciMinerMethod, inExClude, inExCludeCond, phenotypeOnly, conflictCode, hgncIDbyNR, NRText";

	#  Check $InputFileMode for standlone mode
	if (not defined $InputFileMode)
	{   $InputFileMode = '';
	}
                   
    # ------------------------------------------------------------------------
	#      Gene Name Search Mode 
	# ------------------------------------------------------------------------
    my @fileName = glob ($sourceDir."/*.preSciMiner");
    
    #  Prepare output file and get the PMID list from files
    my $outFileName = $targetDir.'SciMinerBase.out';
    open (RESULT, ">>".$outFileName) || LogQuery ("!ERROR: SciMinerDB_Name_Parsing Can't write to file $outFileName");
    my @shortFileName = shortFileNameExtraction (\@fileName);
    my @PMIDList = ();
    for (my $i=0; $i <= $#shortFileName ; $i++) 
    {   my @tmp = split (/\./, $shortFileName[$i]);
        $PMIDList[$i] = $tmp[0];
    }
    
    #  Loop over every file
    for (my $fileNum = 0; $fileNum <= $#fileName; $fileNum++) 
    {   open ( FILE, $fileName[$fileNum] ) || LogQuery ("!ERROR: SciMinerDB_Name_Parsing Can't open file $fileName[$fileNum]");
        #print $fileName[$fileNum]."\n";
        my $tmpParagraphString = '';
        my @targetSentences = ();
        # my $targetSentenceStart = 0;

        # Gather meaningful full text area
        # Sections to be extracted; every section except Reference. But reference can happen before figure or table. Thus figure/table should be checked.
        my @senIDs              = ();
        my %senID2anchor        = ();
        my %senID2sentence      = ();
        my $wholeTextContent    = '';        
        
        #  REMOVE: There is no reference section any more in JUMInerDB, Thus the following step is unnecessary
        #          (only read the sentence into memory)
        while ( <FILE> )
		{   my $line=$_;        $line =~ s/\r|\n//g;
            if ($line =~ /^(\d+) (\S+) (\w+) (\d+) p (\d+) /)
            {   if (($3 eq 'PMID') || ($3 eq 'REFERENCE') || ($3 eq 'REFERENCES')|| ($3 eq 'ACKNOWLEDGMENTS') || ($3 eq 'AUTHORS'))
#             || 		($3 eq 'MESHRN'))
            	{   next;
            	}
            	
            	push @senIDs, $1;
                my $tmpSenID = $1;

                $senID2anchor{$tmpSenID}   = $3;
                $senID2sentence{$tmpSenID} = $'.' ';   #'
                #  Remove special characters from sentence 
                #  10/17/2007: 
                $senID2sentence{$tmpSenID} =~ s/\-|\,|\(|\)|\{|\}/ /g;
                #$wholeTextContentLW			=~ s/\?|\.|\,|\-|\/|\\|\(|\)|\[|\]|\{|\}|\`|\'|\"|\:|\;|\!|\@|\#|\$|\%|\^|\&|\*|\~/ /g;
                $senID2sentence{$tmpSenID} =~ s/\s+/ /g;
                $wholeTextContent .= $senID2sentence{$tmpSenID};
            }
		}   close FILE;		

    
        #  Now proceed with gene name search.
        #  This will be done sentence-wise manner. So the result will be updated at after sentence is completely processed. 
        #  One big difference from Symbol search is first finding the index for name (the first four character). 
        #  Since we are now using the first four character as index, it has significantly reduced search space. (It was three beforehand)
        #  However, note that now we are searching sentence-by-sentence which unfortunately enlarge the search space.
        #  The second difference lies in that name search does not calculate co-exist score since it's already a name. 
        #  If we use the same co-existance score sub-routine, we will always get scores greater than 1, which can't differeniate 
        #  TP from FP.
                
        my %coExistScore            = ();
        my @zeroScoredMatch         = ();
        my %exclusionStatus         = ();
        my %exclusionCond           = ();                       # only the first exclusion is enough if any


        foreach my $senID (@senIDs)
        {   #  Identify symbol
            my $sentence2geneRef = extract_name_case_insensitive (  $PMIDList[$fileNum], $senID, \%senID2anchor, \%senID2sentence, \$wholeTextContent,
                                                                    $UNIQNAMEArray, $UNIQNAME2IDHash, $ID2NameHash, $ID2SymbolHash, 
                                                                    $UNIQNAME2ORIGINAL, $first4codeStart, $first4codeEnd);
            
            #  There was at least one match             
            if (defined $$sentence2geneRef[0])
            {   #  Further calculate additional score by checking adjacent words (up to 2) are gene symbols with score > 0
                foreach my $ref (@{$sentence2geneRef})
                {   #  NEW:11-08-2007 Checking Part Names
                	#  NOTETTTT: There could be some error at this part since there is not querantee that $$ref[2] is hashable key
                	if (defined $$partNameHashRef{$$ref[2]})
                	{   if (check_part_names($partNameHashRef, $ref))     # 2 and 5 are index of actualString and flankingText
                		{   #  If it's part of other name, then just skip it by setting score 0
                			$$ref[4] = 0;
                		}
                	}
                
					#  ---------------------------------------------------------
					#  Check for codon occurrence
					#  ---------------------------------------------------------
					if ($$ref[2] =~ /^[AGCTU]{3} 3$/i)
					{	if ($$ref[5] =~ /([ACGTU]{3}\s{0,1}){2,}/i)
						{   # This belongs to codons
							# set the score zero
							# $$ref[4] = 0;
							push @{$ref}, 2, 35;
						}else
						{   #  Check for exclusion list	
				        	if (defined $$EXCLUDESYMBOLCOND{$$ref[2]})
						    {   if (not defined $exclusionStatus{$$ref[2]})
						        {   ($exclusionStatus{$$ref[2]}, $exclusionCond{$$ref[2]}) = SciMiner_check_exclusion_list (\$wholeTextContent, $$EXCLUDESYMBOLCOND{$$ref[2]});
						        }else
						        {   #  This symbol already has exclusion Status and condition calculated.
						        }
						        #  Add the inclusion information to the current element.
						        push @{$ref}, $exclusionStatus{$$ref[2]}, $exclusionCond{$$ref[2]};
						    }else
						    {   #  Temporarily add inExClude, inExCludeCond
								push @{$ref}, 0, "";
						    }
						}
					}else
					{	#  Check for exclusion list	
			        	if (defined $$EXCLUDESYMBOLCOND{$$ref[2]})
					    {   if (not defined $exclusionStatus{$$ref[2]})
					        {   ($exclusionStatus{$$ref[2]}, $exclusionCond{$$ref[2]}) = SciMiner_check_exclusion_list (\$wholeTextContent, $$EXCLUDESYMBOLCOND{$$ref[2]});
					        }else
					        {   #  This symbol already has exclusion Status and condition calculated.
					        }
					        #  Add the inclusion information to the current element.
					        push @{$ref}, $exclusionStatus{$$ref[2]}, $exclusionCond{$$ref[2]};
					    }else
					    {   #  Temporarily add inExClude, inExCludeCond
							push @{$ref}, 0, "";
					    }
					}
					
                    #  Check the phenotypeOnly option.
                    if (defined $$PhenotypeOnlyToBeExcludedHUGOID{$$ref[0]})
                    {   push @{$ref}, 1;
                    }else
                    {   push @{$ref}, 0;
                    }
                
					#  Add temporary conflict code
					push @{$ref}, 0;
					
					
#					my $colNameString = "pmid, senID, geneID, hgncID, approvedSymbol, 
#										 matchString, actualString, startPos, score, flankingText, 
#										 matchCodeID, tag, SciMinerVersion, SciMinerMethod, inExClude, 
#										 inExCludeCond, phenotypeOnly, conflictCode";
					#  sentence2gene table needs additional two columns (HGNCIDbyNR and NRText) -- These two are not processed by
					#  name mining method. But blank data still needs to be entered.

					#  Update SciMinerDB depending $dbUpdateOption
					my $outputStr		=	"$PMIDList[$fileNum]\t$senID\t$$ID2SciMinerGeneID{$$ref[0]}\t$$ref[0]\t$$ID2SymbolHash{$$ref[0]}\t".
											"$$ref[1]\t$$ref[2]\t$$ref[3]\t$$ref[4]\t$$ref[5]\t".
											"$$ref[6]\t\t$programName\t$$ref[7]\t$$ref[8]\t".
											"$$ref[9]\t$$ref[10]\t$$ref[11]\n";
					if ($dbUpdateOption == 0)
					{	print RESULT 	$outputStr;
						
					}else
					{	if ($InputFileMode)
						{	print RESULT "NAME"."\t".$outputStr;
						}else
						{	my $command = "INSERT INTO `sentence2gene` ($colNameString) VALUES ($PMIDList[$fileNum], $senID, $$ID2SciMinerGeneID{$$ref[0]}, $$ref[0], \"$$ID2SymbolHash{$$ref[0]}\", \"$$ref[1]\", \"$$ref[2]\", $$ref[3], $$ref[4], \"$$ref[5]\", $$ref[6], \"\", \"$programName\", \"$$ref[7]\", $$ref[8], \"$$ref[9]\", $$ref[10], $$ref[11], \"\", \"\")";
							
		                	$dbh->do($command) || LogQuery("! Error in inserting into SciMinerDB... $command");
					
							#  Retrieve the sen2geneID for this entry
							my $sth                 = $dbh->prepare("SELECT sen2geneID FROM sentence2gene ORDER BY sen2geneID DESC LIMIT 1");
							$sth->execute();
						
							my @row                 = $sth->fetchrow_array;#($result);
							if (defined $row[0])
							{	print RESULT $row[0]."\t".$outputStr;
							}							
						}
					}
                }
            }else
            {   # print RESULT $PMIDList[$fileNum]."\t0\n";
            }
            #  Update SciMinerDB
        }
        
        #  Update the SciMinerDB for mined document in the table 'document' column 'statusMined'
        #  statusMined: 0   ==> not mined yet
        #               1   ==> mining completed.
        #  Now, finally update the SciMinerDB
        if (!$InputFileMode)
		{	$dbh->do("UPDATE document SET statusMined=1 WHERE docID = $$pmid2docIDRef{$PMIDList[$fileNum]}");
		}
    }   close RESULT;
}  # End of Subroutin HUGO_Symbol_Name_Parsing





# ---------------------------------------------------------------------------
# sub extract_name_case_insensitive
# ---------------------------------------------------------------------------
# Last modified: 10/03/2007
# Description: This subroutin perform the comparing task. This is called
#              by HUGO_Symbol_Name_Parsing
# ---------------------------------------------------------------------------
sub extract_name_case_insensitive
{   my ($pmid, 
        $senID, 
        $senID2anchorRef, 
        $senID2sentenceRef, 
        $wholeTextContentRef,
        $UniqNameArrayRef,
        $UniqName2IDHashRef,
        $ID2NameHashRef,
        $ID2SymbolHashRef,
        $UniqName2OriginalHashRef, 
        $first4codeStartHashRef, 
        $first4codeEndHashRef, 
        $EXCLUDESYMBOLCOND        ) = @_;

    use strict;

	# Select out only that has three letter codes in the hashes of %{$first4codeStart}
	my $transferredContent = lc ($$senID2sentenceRef{$senID});

    #$transferredContent =~ s/[\.|\?|\!|\,] / /g;
    #  Note that there is no length 4 gene name any more. 
    #  Also note that there is no gene name with double space.
    
    my $tmp4ChrCode                 = '';
    my %searchFourChrCodesCheck     = ();
    my @sentence2gene               = ();
    my $tmpMatch					= '';
    my $tmpString					= '';
    my @tmpSlashSplit				= ();
    my $tmpWord						= '';
    my $localTmpStr					= '';
    my $tmpHUGOID					= '';
    
    #  TODO: Check whether the last word is required for checking. 
    
    my @oriSplitBySpace = split (/ /, $transferredContent);
    for (my $i=0; $i <= $#oriSplitBySpace - 1; $i++)
    {   #  In case the word is shorter than 4
        if (length($oriSplitBySpace[$i]) < 4)
        {   #  Merge with the following word if defined
            $tmpString = $oriSplitBySpace[$i].' '.$oriSplitBySpace[$i+1];
            $tmp4ChrCode = substr($tmpString, 0, 4) || next;
            if (defined $$first4codeStartHashRef{$tmp4ChrCode})
            {   if (not defined $searchFourChrCodesCheck{$tmp4ChrCode})
                {   $searchFourChrCodesCheck{$tmp4ChrCode} = 1;
                }
            }
        }else
        {   $tmp4ChrCode = substr($oriSplitBySpace[$i], 0, 4) || next;
            if (defined $$first4codeStartHashRef{$tmp4ChrCode})
            {   if (not defined $searchFourChrCodesCheck{$tmp4ChrCode})
                {   $searchFourChrCodesCheck{$tmp4ChrCode} = 1;
                }
            }
        }
        
        #  If there is a slash '/' in the string, then split by slash
		if ($oriSplitBySpace[$i] =~ /\//)
		{   @tmpSlashSplit	= split(/\//, $oriSplitBySpace[$i]);
			#  Process only the second half
			if ((defined $tmpSlashSplit[1]) && ($tmpSlashSplit[1] ne ""))
			{   #  In case the word is shorter than 4
				if (length($tmpSlashSplit[1]) < 4)
				{   if (defined $tmpSlashSplit[2])
					{	# if there is another word, then skip this
					}else
					{	#  Merge with the following word if defined
						$tmpString = $tmpSlashSplit[1].' '.$oriSplitBySpace[$i+1];
						$tmp4ChrCode = substr($tmpString, 0, 4) || next;
						if (defined $$first4codeStartHashRef{$tmp4ChrCode})
						{   if (not defined $searchFourChrCodesCheck{$tmp4ChrCode})
						    {   $searchFourChrCodesCheck{$tmp4ChrCode} = 1;
						    }
						}
					}
				}else
				{   $tmp4ChrCode = substr($tmpSlashSplit[1], 0, 4) || next;
				    if (defined $$first4codeStartHashRef{$tmp4ChrCode})
				    {   if (not defined $searchFourChrCodesCheck{$tmp4ChrCode})
				        {   $searchFourChrCodesCheck{$tmp4ChrCode} = 1;
				        }
				    }
				}
			}
		}
        
        #  TODO: I need to confirm how much of the following cases are out there.
        if (substr($oriSplitBySpace[$i], 0, 1) =~ /[\[|\]|\{|\}|\(|\)]/)
        {   $tmpWord = substr($oriSplitBySpace[$i], 1, length($oriSplitBySpace[$i]) - 1);
            if (length($tmpWord) < 4)
            {   #  Merge with the following word if defined
                $tmpString = $tmpWord.' '.$oriSplitBySpace[$i+1];
                $tmp4ChrCode = substr($tmpString, 0, 4) || next;
                if (defined $$first4codeStartHashRef{$tmp4ChrCode})
                {   if (not defined $searchFourChrCodesCheck{$tmp4ChrCode})
                    {   $searchFourChrCodesCheck{$tmp4ChrCode} = 1;
                    }
                }
            }else
            {   $tmp4ChrCode = substr($tmpWord, 0, 4) || next;
                if (defined $$first4codeStartHashRef{$tmp4ChrCode})
                {   if (not defined $searchFourChrCodesCheck{$tmp4ChrCode})
                    {   $searchFourChrCodesCheck{$tmp4ChrCode} = 1;
                    }
                }
            }
        }
    }
    
    foreach my $chr4Code (keys %searchFourChrCodesCheck)
    {   for (my $i=$$first4codeStartHashRef{$chr4Code}; $i <= $$first4codeEndHashRef{$chr4Code}; $i++)
        {   #print "$$UniqNameArrayRef[$i]\n";
            $localTmpStr  = $transferredContent;
            while($localTmpStr =~ /.{0,200}\b$$UniqNameArrayRef[$i](\b.{0,200})/)
            {   # This is a match
            	$tmpMatch        	= $&;
            	$localTmpStr		= ($1).$';
            	$tmpMatch			=~ s/\"/\\\"/g;

                $tmpHUGOID = $$UniqName2IDHashRef{$$UniqNameArrayRef[$i]};
                if (not defined $sentence2gene[0])
			    {   $sentence2gene[0]->[0]  = $tmpHUGOID;
			    }else
			    {   $sentence2gene[$#sentence2gene+1]->[0] = $tmpHUGOID;
			    }

                #  Add additional information 
                push @{$sentence2gene[$#sentence2gene]}, $$UniqName2OriginalHashRef{$$UniqNameArrayRef[$i]};
                push @{$sentence2gene[$#sentence2gene]}, $$UniqNameArrayRef[$i];
                push @{$sentence2gene[$#sentence2gene]}, 0;                         # startPos
                push @{$sentence2gene[$#sentence2gene]}, 1;                         # score

				#  Get the flanking region text                
                push @{$sentence2gene[$#sentence2gene]}, $tmpMatch;                 # flanking text
                #if ($tmpMatch =~ /(\S+\s?){0,5}\b$$UniqNameArrayRef[$i]\b(\s?\S+){0,5}/)
                #{   push @{$sentence2gene[$#sentence2gene]}, $&;                        # flanking text
                #}else
                #{   push @{$sentence2gene[$#sentence2gene]}, $tmpMatch;                 # flanking text
                #}
                
                push @{$sentence2gene[$#sentence2gene]}, 7;                         # matchCode
                push @{$sentence2gene[$#sentence2gene]}, 2;                         # methodCode    (NAME_LOWER_ALL)
            }
        }
    }
    return ( \@sentence2gene );
}












#  ---------------------------------------------------------------------------
#  ---------------------------------------------------------------------------
#
#  Section III.  Single Only
#
#  ---------------------------------------------------------------------------
#  ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# sub SciMinerDB_Name_Parsing_Single
# ---------------------------------------------------------------------------
# Last modified: 10/22/2007
# Description: This subroutin parses out gene SYMBOLS with flanking
#               text surrounding mined names from full text content.
# Return: No return
# Version 4 : Conflicting symbols are selected based on the co-occurrence
#             score.
# ---------------------------------------------------------------------------
sub SciMinerDB_Name_Parsing_Single
{   my ($annoENVRef, 
        $sourceDir, 
        $targetDir,
        $ID2SciMinerGeneID,
		$ID2SymbolHash, 
		$ID2NameHash,
		$UNIQNAMEArray, 
		$UNIQNAME2IDHash,
		$UNIQNAME2ORIGINAL, 
		$first4codeStart,
		$first4codeEnd,
        $programName, 
        $dbh,
        $PhenotypeOnlyToBeExcludedHUGOID, 
        $pmid,
        $docID,
        $partNameHashRef                          )= @_; 
        

    print "  ! Starting name parsing \n";
    #  Set Column String to be inserted.
    my $colNameString = "pmid, senID, geneID, hgncID, approvedSymbol, matchString, actualString, startPos, score, flankingText, matchCodeID, tag, SciMinerVersion, SciMinerMethod, inExClude, inExCludeCond, phenotypeOnly";

                   
    # ------------------------------------------------------------------------
	#      Gene Name Search Mode 
	# ------------------------------------------------------------------------
    my $preSciMinerFile  = "$sourceDir/$pmid.preSciMiner";
    if (! -f $preSciMinerFile)
    {   return();
    }
    
    #  Prepare output file
    my $outFileName = $targetDir.'SciMinerBase.out';
    open (RESULT, ">>".$outFileName) || LogQuery ("!ERROR: SciMinerDB_Name_Parsing Can't write to file $outFileName");
    
    #  Loop over every file
    {   open ( FILE, $preSciMinerFile ) || LogQuery ("!ERROR: Can't open $preSciMinerFile");
        #print $preSciMinerFile."\n";
        my $tmpParagraphString = '';
        my @targetSentences = ();
        # my $targetSentenceStart = 0;

        # Gather meaningful full text area
        # Sections to be extracted; every section except Reference. But reference can happen before figure or table. Thus figure/table should be checked.

        
        my @senIDs              = ();
        my %senID2anchor        = ();
        my %senID2sentence      = ();
        my $wholeTextContent    = '';        
        
        #  REMOVE: There is no reference section any more in JUMInerDB, Thus the following step is unnecessary
        #          (only read the sentence into memory)
        while ( <FILE> )
		{   my $line=$_;        $line =~ s/\r|\n//g;
            if ($line =~ /^(\d+) (\d+) (\w+) (\d+) p (\d+) /)
            {   if (($3 eq 'PMID') || ($3 eq 'REFERENCE') || ($3 eq 'REFERENCES') || ($3 eq 'ACKNOWLEDGMENTS'))
            	{   next;
            	}
            	push @senIDs, $1;
                my $tmpSenID = $1;
                #print $line."\n";
                #print $tmpSenID."\n";
                $senID2anchor{$tmpSenID}   = $3;
                $senID2sentence{$tmpSenID} = $'.' ';   #'
                #  Remove special characters from sentence 
                #  10/17/2007: 
                #if (not defined $senID2sentence{$1})
                #{   print "senID is $1   is not defined \n";
                #}
                #if (not defined $senID2sentence{$tmpSenID})
                #{   print "senID is $tmpSenID is not defined\n";
                #}
                $senID2sentence{$tmpSenID} =~ s/\-|\,|\(|\)|\{|\}|\[|\]/ /g;
                $senID2sentence{$tmpSenID} =~ s/\s+/ /g;
                $wholeTextContent .= $senID2sentence{$tmpSenID};
                #print $senID2sentence{$tmpSenID}."\n";
            }
		}   close FILE;		

    
        #  Now proceed with gene name search.
        #  This will be done sentence-wise manner. So the result will be updated at after sentence is completely processed. 
        #  One big difference from Symbol search is first finding the index for name (the first four character). 
        #  Since we are now using the first four character as index, it has significantly reduced search space. (It was three beforehand)
        #  However, note that now we are searching sentence-by-sentence which unfortunately enlarge the search space.
        #  The second difference lies in that name search does not calculate co-exist score since it's already a name. 
        #  If we use the same co-existance score sub-routine, we will always get scores greater than 1, which can't differeniate 
        #  TP from FP.
                
            
        my %coExistScore            = ();
        my @zeroScoredMatch         = ();
        foreach my $senID (@senIDs)
        {   #  Identify symbol
            my $sentence2geneRef = extract_name_case_insensitive (  $pmid, $senID, \%senID2anchor, \%senID2sentence, \$wholeTextContent,
                                                                    $UNIQNAMEArray, $UNIQNAME2IDHash, $ID2NameHash, $ID2SymbolHash, 
                                                                    $UNIQNAME2ORIGINAL, $first4codeStart, $first4codeEnd);
            
            #  There was at least one match             
            if (defined $$sentence2geneRef[0])
            {   #  Further calculate additional score by checking adjacent words (up to 2) are gene symbols with score > 0
                
                foreach my $ref (@{$sentence2geneRef})
                {   #  NEW:11-08-2007 Checking Part Names
                	#  NOTETTTT: There could be some error at this part since there is not querantee that $$ref[2] is hashable key
                	if (defined $$partNameHashRef{$$ref[2]})
                	{   if (check_part_names($partNameHashRef, $ref))     # 2 and 5 are index of actualString and flankingText
                		{   #  If it's part of other name, then just skip it by setting score 0
                			$$ref[4] = 0;
                		}
                	}
                
                
                
                	#  Temporarily add inExClude, inExCludeCond
                    push @{$ref}, 0, "";
                    
                    #  Check the phenotypeOnly option.
                    if (defined $$PhenotypeOnlyToBeExcludedHUGOID{$$ref[0]})
                    {   push @{$ref}, 1;
                    }else
                    {   push @{$ref}, 0;
                    }
                
                    my $command = "INSERT INTO `sentence2gene` ($colNameString) VALUES ($pmid, $senID, $$ID2SciMinerGeneID{$$ref[0]}, $$ref[0], \"$$ID2SymbolHash{$$ref[0]}\", \"$$ref[1]\", \"$$ref[2]\", $$ref[3], $$ref[4], \"$$ref[5]\", $$ref[6], \"\", \"$programName\", \"$$ref[7]\", $$ref[8], \"$$ref[9]\", $$ref[10])";
                    $dbh->do($command);
            
                    #  Retrieve the sen2geneID for this entry
                    my $sth                    = $dbh->prepare("SELECT sen2geneID FROM sentence2gene ORDER BY sen2geneID DESC LIMIT 1");
                    $sth->execute();
                    my @row                 = $sth->fetchrow_array;#($result);
                    print RESULT $row[0]."\t".$pmid."\t".$senID."\t".$$ID2SciMinerGeneID{$$ref[0]}."\t".$$ref[0]."\t".$$ID2SymbolHash{$$ref[0]}."\t".$$ref[1]."\t".$$ref[2]."\t".$$ref[3]."\t".$$ref[4]."\t".$$ref[5]."\t".$$ref[6]."\t"."\t".$programName."\t".$$ref[7]."\t".$$ref[8]."\t".$$ref[9]."\t".$$ref[10]."\n";
                }
            }else
            {   # print RESULT $pmid."\t0\n";
            }
            #  Update SciMinerDB
        }
        
        #  Update the SciMinerDB for mined document in the table 'document' column 'statusMined'
        #  statusMined: 0   ==> not mined yet
        #               1   ==> mining completed.
        #  Now, finally update the SciMinerDB
        $dbh->do("UPDATE document SET statusMined=1 WHERE docID = $docID");
    }   close RESULT;
}  # End of Subroutin HUGO_Symbol_Name_Parsing




### `
# sub SciMinerDB_Symbol_Parsing_Single
# ---------------------------------------------------------------------------
# Last modified: 10/22/2007
# Description: This subroutin parses out gene SYMBOLS with flanking
#               text surrounding mined names from full text content.
# Return: No return
# Version 4 : Conflicting symbols are selected based on the co-occurrence
#             score.
# ---------------------------------------------------------------------------
sub SciMinerDB_Symbol_Parsing_Single
{   my ($annoENVRef, 
        $sourceDir, 
        $targetDir,
        $ID2SciMinerGeneID,
		$ID2SymbolHash, 
		$ID2NameHash,
		$ID2GeneIDHash, 
		$UNIQSYMArray, 
		$UNIQSYM2IDHash,
		$UNIQNAMEArray, 
		$UNIQNAME2IDHash,
		$UNIQSYMHASHLOWKEY2HUGO, 
		$UNIQSYMHASHLOWKEY2ORIGINAL, 
		$UNIQNAMEHASHLOWKEY2ORIGINAL, 
        $ID2NameArray, 
        $INCLUDESYMBOLMODE, 
        $INCLUDESYMBOLCOND, 
        $EXCLUDESYMBOLCOND,
        $PhenotypeOnlyToBeExcludedHUGOID,
        $DUPSYM2HUGO, 
        $NonRedundantID2NameArray, 
        $NonRedundantID2NameTypeArray, 
        $programName, 
        $dbh,
        $pmid,
        $docID                      )= @_; 
        
	my ($pubmedID, $abstract, $title, @titleSplit,
		@abstractLineSplit, @foundHUGOContent, $foundHUGONumber);

    #  Set Column String to be inserted.
    my $colNameString = "pmid, senID, geneID, hgncID, approvedSymbol, matchString, actualString, startPos, score, flankingText, matchCodeID, tag, SciMinerVersion, SciMinerMethod, inExClude, inExCludeCond, phenotypeOnly";
                

                
                
    #  Search option
    my $checkFlankingGeneProteinOption  = 1;
    my $checkSameBlockAdjacentGene      = 1;
    my $checkGeneSymbolLength           = 6;


    # ------------------------------------------------------------------------
	#      Gene Symbol Search Mode 
	# ------------------------------------------------------------------------
    my $preSciMinerFile  = "$sourceDir/$pmid.preSciMiner";
    if (! -f $preSciMinerFile)
    {   return();
    }
    
    print "  ! Starting symbol parsing ...";
    
    #  Prepare output file
    my $outFileName = $targetDir.'SciMinerBase.out';
    open (RESULT, ">".$outFileName) || print "! Can't write to file\n";
    
    #  Loop over every file
    {   open ( FILE, $preSciMinerFile ) || print "can't open file\n";
        my $tmpParagraphString = '';
        my @targetSentences = ();
        
        # Gather meaningful full text area
        # Sections to be extracted; every section except Reference. But reference can happen before figure or table. Thus figure/table should be checked
        my @senIDs              = ();
        my %senID2anchor        = ();
        my %senID2sentence      = ();
        my $wholeTextContent    = '';        
        
        #  REMOVE: There is no reference section any more in JUMInerDB, Thus the following step is unnecessary
        #          (only read the sentence into memory)
        while ( <FILE> )
		{   my $line=$_;        $line =~ s/\r|\n//g;
            if ($line =~ /^(\d+) (\d+) (\w+) (\d+) p (\d+) /)
            {   if (($3 eq 'PMID') || ($3 eq 'REFERENCE') || ($3 eq 'REFERENCES')|| ($3 eq 'ACKNOWLEDGMENTS'))
            	{   next;
            	}
            #	push @senIDs, $1;
            #    $senID2anchor{$1}   = $3;
            #    $senID2sentence{$1} = $'.' ';   #'
            #    $wholeTextContent .= $senID2sentence{$1};
            #    
                
                #  MESHRN text is only used for scoring purpose
                if ($3 ne 'MESHRN')
                {   push @senIDs, $1;
                        $senID2anchor{$1}   = $3;
                        $senID2sentence{$1} = $'.' ';   #'
                }
            	#$wholeTextContent .= $senID2sentence{$1};
                $wholeTextContent .= $'.' ';
                
                
            }
		}   close FILE;		

    
        #  Now proceed with gene symbol search.
        #  This will be done sentence-wise manner. So the result will be updated at after sentence is completely processed. 
        
        my %coExistScore            = ();
        my @zeroScoredMatch         = ();
        my @semiFinalMatch          = ();
        
        #  Exclusion/Inclusion list applies to all the sentence
        my %exclusionStatus         = ();
        my %exclusionCond           = ();                       # only the first exclusion is enough if any
        my %inclusionStatus         = ();
        my %inclusionCond           = ();        
        my %hugoID2score            = ();
        my %coExistScoreMatch       = ();
        my %coExistScoreHUGOID      = ();
        
        #  Term frequency
        my %matchTerm2TermFreq      = ();
        my %docTermFreqRef          = ();

        #  Loop over every sentence             
        foreach my $senID (@senIDs)
        {   #  Identify symbol
            #  Mine the sentence for any symbol and default coExistScore.
            my $sentence2geneRef = extract_symbol_case_sensitive($pmid, $senID, \%senID2anchor, \%senID2sentence, \$wholeTextContent,
                                            $UNIQSYM2IDHash, $ID2SymbolHash, 3,
                                            $UNIQSYMHASHLOWKEY2HUGO, $UNIQSYMHASHLOWKEY2ORIGINAL, $ID2NameArray,
                                            $NonRedundantID2NameArray, $NonRedundantID2NameTypeArray, $ID2GeneIDHash, \%coExistScore,         
                                            $DUPSYM2HUGO, \%hugoID2score, \%coExistScoreMatch, \%coExistScoreHUGOID,
                                            \%matchTerm2TermFreq, \%docTermFreqRef);

            #  There was at least one match (symbol) found  
            if (defined $$sentence2geneRef[0])
            {   #  ------------------------------------------------------------------------------
                #    Perform additional score calculation based on the context
                #  ------------------------------------------------------------------------------
                #  1. Look for adjacent words 'gene(s)' / 'protein(s)' / '
                #     ==> maybe we can add something like 'receptor(s) for' but currently only use gene and protein
                if ($checkFlankingGeneProteinOption)
                {   foreach my $ref (@{$sentence2geneRef})
                    {   my $flankGeneScore = Calculate_Flanking_Word_Score_For_Gene(\$wholeTextContent, $$ref[2]);
                        if (($$ref[4] == 0) && ($flankGeneScore > 0))
                        {   $$ref[5] = 3;
                        }
                        #  Add the flank score anyway
                        $$ref[4] += $flankGeneScore;
                    }
                }
                
                # -------------------------------------------------------------------------------
                #  2. Look for any other gene in the same word block
                #     ?? Do I have to do this check only for zero-scored match?
                my %pos2scoreCheck          = ();
                my @localZeroScoredMatch    = ();
                my @tmpNonZeroScoredMatch   = ();
                
                if ($checkSameBlockAdjacentGene)
                {   foreach my $ref (@{$sentence2geneRef})
                    {   if ($$ref[4] > 0)
                        {   $pos2scoreCheck{$$ref[3]} = $$ref[4];
                            push @tmpNonZeroScoredMatch, $ref;
                        }else
                        {   push @localZeroScoredMatch, $ref;
                            next;
                        }
                    }
                    
                    #  3. Look for any adjacent gene up to two words distance of gene symbols with score > 0
                    #  Now check the score of adjacent words
                    #  For those zero-score match, add $senID to the array
                    if (defined $localZeroScoredMatch[0])
                    {   foreach my $ref (@localZeroScoredMatch)
                        {   #  If it is in the same word with other gene, this probably mean a gene forming a complex or alternative name
                            if ((($$ref[3]-1)>=0) && (defined $pos2scoreCheck{($$ref[3]-1)}))
                            {   $$ref[5] = 5;
                                $$ref[4] += 0.2;
                            }
                            if (defined $pos2scoreCheck{($$ref[3]+1)})
                            {   $$ref[5] = 5;
                                $$ref[4] += 0.2;
                            }
                            if ((($$ref[3]-2)>=0) && (defined $pos2scoreCheck{($$ref[3]-2)}))
                            {   $$ref[5] = 6;
                                $$ref[4] += 0.1;
                            }
                            if (defined $pos2scoreCheck{($$ref[3]+2)})
                            {   $$ref[5] = 6;
                                $$ref[4] += 0.1;
                            }
                            if (defined $pos2scoreCheck{$$ref[3]})
                            {   #  This case is the symbol is in the same block with other gene
                                $$ref[5] = 4;
                                $$ref[4] += 0.3;
                            }

                            push @tmpNonZeroScoredMatch, $ref;
                        }
                    }
                    
                }else
                {   @tmpNonZeroScoredMatch = @{$sentence2geneRef};
                }
            
                #  Add the senID to the end of the each array
                foreach my $ref (@tmpNonZeroScoredMatch)
                {   push @{$ref}, $senID;
                    push @semiFinalMatch, $ref;
                }
            }   #  End of if (defined $$sentence2geneRef[0])
        }   #  End of foreach my $senID (@senIDs)
        

        #  --------------------------------------------------------------------------------------------
        #  TODO: Do not use the maximum score assignment. 
        #  Note: max score is not used since it would be
        #  Now take care of the flanking gene score
        #my %maxBySymbol     = ();
        #foreach my $ref (@zeroScoredMatch)
        #{   #  First get the maximum of that symbol (matched String)
        #    if (not defined $maxBySymbol{$$ref[1]})
        #    {   $maxBySymbol{$$ref[1]} = $$ref[3];
        #    }else
        #    {   if ($maxBySymbol{$$ref[1]} < $$ref[3])
        #        {   $maxBySymbol{$$ref[1]} = $$ref[3];
        #        }
        #    }
        #}
        
        ##  Now use the calculated maximum for all matched symbol. 
        ##  This way, same symbol will have the same score (flanking_gene)
        #foreach my $ref (@zeroScoredMatch)
        #{   #  First get the maximum of that symbol (matched String)
        #    $$ref[3] = $maxBySymbol{$$ref[1]};
        #    foreach my $string (@{$ref})
        #    {   print $string."\t";
        #    }   print "\n";
        #
        #    my $command = "INSERT INTO `sentence2gene` ($colNameString) VALUES ($pmid, $$ref[7], $$ID2SciMinerGeneID{$$ref[0]}, $$ref[0], \"$$ID2SymbolHash{$$ref[0]}\", \"$$ref[1]\", \"$$ref[2]\", $$ref[3], $$ref[4], \"\", $$ref[5], \"\", \"$programName\", \"$$ref[6]\")";
        #    print $command."\n\n";
        #    $dbh->do($command);
        #    
        #}
        
        
        
        #  Check exclusion/inclusion condition
        #  -------------------------------------------------------------------                
        #  Check inclusion/exclusion list
        #  -------------------------------------------------------------------                
        #  inclusion/exclusion will ALWAYS be performed for any new sentence
        foreach my $ref (@semiFinalMatch)
        {   my $tmpGeneSymbol   = lc($$ref[2]);     # $$ref[2] is the actual matching string
            my $tmpInExCode     = 0;
            my $tmpInExDetail   = 0;
            
        	#  Always check advancing word 'thank(s)' for any positive scored symbol. 
        	#  Is this really necessary? Yes, we can illiminate some of the false-positives
        	#  But in terms of processing time, wouldn't this ????
        	#  This only applies when the matchcode is 2 ==> Lowered match. 
        	if ($$ref[4] > 0) 
        	{   if ($$ref[5] == 2)      # matchcode is 2
        		{   if (($$ref[7] =~ /thanks?/) || ($$ref[7] =~ /acknowledge/))
	        	    {   # There is the word 'thank/s/', then probably matching symbol is very likely to be a false-positive if it's matched by lowered
	        	    	# Don't change the score, just update the status
	        	    	# $$ref[4] = 0;
	        	    	$tmpInExCode        = 2;
	        	    	$tmpInExDetail      = 33;
	        	    }elsif ($$ref[7] =~ /$$ref[2] et al\b/)
	        	    {	#$$ref[4] = 0;
	        	        #if ($$ref[7] =~ /$$ref[2]\b(\S*\s?){0,3} et al/)
	        	        #{   #  There is such terms with Symbol (lowered) <up to two more words> et al
	        	        #    $$ref[4] = 0;
	        	        #}
	        	    	$tmpInExCode        = 2;
	        	    	$tmpInExDetail      = 34;	        	        
	        	    }
        		}
        		
        		#  --------------------------------------------------------------------------------
	            #  Check if the symbol is simply a codon or not
	            elsif ($$ref[7] =~ /[Cc]ell/)
        	    {   #  Check for any occurrence of cell line related format
        	        if (check_cell_line_name($$ref[2], $$ref[7]))
        	        {   $tmpInExCode    = 2;
        	            $tmpInExDetail  = 32;	
        	        }
        	    }
        	    
        	    if ($$ref[2] =~ /^[AGCTU]{3}$/i)
	        	{   if ($$ref[7] =~ /([ACGTU]{3}\s{0,1}){2,}/i)
	        		{   # The symbol belongs to codons
	        			# set the score zero
	        			# $$ref[4] = 0;
	        		    $tmpInExCode    = 2;
        	            $tmpInExDetail  = 35;	
	        		}
	        	}
        	}
        	
   	
        	
            if ($$ref[4] > 0)
            {   #  If the score is greater than zero
                #  In this case, the gene is checked against the EXCLUDE list
                #  Exclusion is ALWAYS conditional, thus no need to check mode.
                
                if ($tmpInExCode == 2)
                {   #  Check any customary inclusion list
                    if (defined $$INCLUDESYMBOLMODE{$tmpGeneSymbol})
                    {   if ( $$INCLUDESYMBOLMODE{$tmpGeneSymbol} )                  # if 1 ==> conditional
                        {   if (not defined $inclusionStatus{$tmpGeneSymbol})
                            {   ($inclusionStatus{$tmpGeneSymbol}, $inclusionCond{$tmpGeneSymbol}) = SciMiner_check_inclusion_list (\$wholeTextContent, $$INCLUDESYMBOLCOND{$tmpGeneSymbol});
                            }else
                            {   #  This symbol already has inclusion Status and condition calculated.
                            }
                        }else                                                       # else is non-conditional ==> just include
                        {   # No need to check condition. just include them
                            $inclusionStatus{$tmpGeneSymbol}    = 1;
                            $inclusionCond{$tmpGeneSymbol}      = $tmpGeneSymbol.';';
                        }
                        
                        #  Add the inclusion information to the current element.
                        push @{$ref}, $inclusionStatus{$tmpGeneSymbol}, $inclusionCond{$tmpGeneSymbol};
                    }else
                    {   #  This entry has already been marked to be excluded
                        push @{$ref}, $tmpInExCode, $tmpInExDetail;
                    }
                }elsif (defined $$EXCLUDESYMBOLCOND{$tmpGeneSymbol})
                {   if (not defined $exclusionStatus{$tmpGeneSymbol})
                    {   ($exclusionStatus{$tmpGeneSymbol}, $exclusionCond{$tmpGeneSymbol}) = SciMiner_check_exclusion_list (\$wholeTextContent, $$EXCLUDESYMBOLCOND{$tmpGeneSymbol});
                    }else
                    {   #  This symbol already has exclusion Status and condition calculated.
                    }
                    #  Add the inclusion information to the current element.
                    push @{$ref}, $exclusionStatus{$tmpGeneSymbol}, $exclusionCond{$tmpGeneSymbol};
                }else
                {   #  This mined symbol is not currently included in the INCLUDE list
                    #  Nothing more to do at this moment. 
                    push @{$ref}, 0, "";
                }
            }else
            {   #  If the score is not greater than zero, ==> the score is zero.
                #  In this case, the gene is checked against the INCLUDE list
                if (defined $$INCLUDESYMBOLMODE{$tmpGeneSymbol})
                {   if ( $$INCLUDESYMBOLMODE{$tmpGeneSymbol} )                  # if 1 ==> conditional
                    {   if (not defined $inclusionStatus{$tmpGeneSymbol})
                        {   ($inclusionStatus{$tmpGeneSymbol}, $inclusionCond{$tmpGeneSymbol}) = SciMiner_check_inclusion_list (\$wholeTextContent, $$INCLUDESYMBOLCOND{$tmpGeneSymbol});
                        }else
                        {   #  This symbol already has inclusion Status and condition calculated.
                        }
                    }else                                                       # else is non-conditional ==> just include
                    {   # No need to check condition. just include them
                        $inclusionStatus{$tmpGeneSymbol}    = 1;
                        $inclusionCond{$tmpGeneSymbol}      = $tmpGeneSymbol.';';
                    }
                    
                    #  Add the inclusion information to the current element.
                    push @{$ref}, $inclusionStatus{$tmpGeneSymbol}, $inclusionCond{$tmpGeneSymbol};
                }else
                {   #  This mined symbol is not currently included in the INCLUDE list
                    #  Check the symbol length check option. 
                    #  If the option is on and the symbol is not included in the EXCLUSION list mark it as INCLUDE
                    if ($checkGeneSymbolLength)
                    {   if (length($tmpGeneSymbol) >= $checkGeneSymbolLength)
                        {   #  Only include when it's not in the EXCLUSION list
                            if (not defined $exclusionStatus{$tmpGeneSymbol})
                            {   ($exclusionStatus{$tmpGeneSymbol}, $exclusionCond{$tmpGeneSymbol}) = SciMiner_check_exclusion_list (\$wholeTextContent, $$EXCLUDESYMBOLCOND{$tmpGeneSymbol});
                            }
                            
                            if ($exclusionStatus{$tmpGeneSymbol})
                            {   #  This symbol is in the exclusion list
                                push @{$ref}, $exclusionStatus{$tmpGeneSymbol}, $exclusionCond{$tmpGeneSymbol};
                            }else
                            {   #  Add this as LongSymbol inclusion; code = 2
                                push @{$ref}, 2, "LongSymbol";
                            }
                        }else
                        {   #  If the length is shorter than the threshold, just do nothing
                            push @{$ref}, 0, "";
                        }
                    }
                }
            }   #  End of else        
        }   #  End of foreach my $ref (@semiFinalMatch)


        #  Process phenotypeOnly symbol
        foreach my $ref (@semiFinalMatch)
        {   if (defined $$PhenotypeOnlyToBeExcludedHUGOID{$$ref[0]})
            {   push @{$ref}, 1;
            }else
            {   push @{$ref}, 0;
            }
            
            #  Generate commands for DB Insertion.
            #  $senID is $$ref[7]
            my $command = "INSERT INTO `sentence2gene` ($colNameString) VALUES ($pmid, $$ref[8], $$ID2SciMinerGeneID{$$ref[0]}, $$ref[0], \"$$ID2SymbolHash{$$ref[0]}\", \"$$ref[1]\", \"$$ref[2]\", $$ref[3], $$ref[4], \"$$ref[7]\", $$ref[5], \"\", \"$programName\", \"$$ref[6]\", $$ref[9], \"$$ref[10]\", $$ref[11])";
            $dbh->do($command);
            
            #  Retrieve the sen2geneID for this entry
            my $sth                 = $dbh->prepare("SELECT sen2geneID FROM sentence2gene ORDER BY sen2geneID DESC LIMIT 1");
            $sth->execute();
            my @row                 = $sth->fetchrow_array;#($result);
            print RESULT $row[0]."\t".$pmid."\t".$$ref[8]."\t".$$ID2SciMinerGeneID{$$ref[0]}."\t".$$ref[0]."\t".$$ID2SymbolHash{$$ref[0]}."\t".$$ref[1]."\t".$$ref[2]."\t".$$ref[3]."\t".$$ref[4]."\t".$$ref[7]."\t".$$ref[5]."\t"."\t".$programName."\t".$$ref[6]."\t".$$ref[9]."\t".$$ref[10]."\t".$$ref[11]."\n";
            
        }
        #  Now, finally update the SciMinerDB
        $dbh->do("UPDATE document SET statusMined=1 WHERE docID = $docID");
        
    #  End of the loop every file    
    }   close RESULT;
}  # End of Subroutin HUGO_Symbol_Name_Parsing























#  ---------------------------------------------------------------------------
#  ---------------------------------------------------------------------------
#
#  Section IV.  Common 
#
#  ---------------------------------------------------------------------------
#  ---------------------------------------------------------------------------

sub get_flanking_text_for_symbol_match
{   my $sentenceSplitRef    = shift;
    my $wordPosition        = shift;
    my $extLength           = shift;
    
    my $startPos            = 0;
    my $endPos              = scalar @{$sentenceSplitRef} - 1;
    my $startCalc           = $wordPosition - $extLength;
    my $endCalc             = $wordPosition + $extLength;
    if ($startCalc > $startPos)
    {   $startPos = $startCalc;
    }
    if ($endCalc < $endPos)
    {   $endPos = $endCalc;
    }

    my $flankingText        = $$sentenceSplitRef[$startPos];
    for (my $i=$startPos+1; $i <= $endPos; $i++)
    {   $flankingText      .= ' '.$$sentenceSplitRef[$i];
    }    
    return ($flankingText);
}

sub check_cell_line_name
{   my $shortString     = shift;
    my $targetString    = shift;

    if ($targetString =~ /\b$shortString (cancer )?cell ?lines?\b/)
    {   return(1);
    }
    if ($targetString =~ /\b$shortString (stem )?cell ?lines?\b/)
    {   return(1);
    }
    if ($targetString =~ /\b[Cc]ell ?lines? $shortString\b/)
    {   return(1);
    }
    if ($targetString =~ /\b$shortString (cancer )?cells\b/)
    {   return(1);
    }
    if ($targetString =~ /\b$shortString (stem )?cells\b/)
    {   return(1);
    }
    return (0);
}    	

sub check_part_names
{	my $partNameHashRef		= shift;
	my $ref					= shift;
	my $astringIndex		= 2;
	my $flankingIndex		= 5;

	my @arraysOfTermsHUGOIDs	= @{$$partNameHashRef{$$ref[$astringIndex]}};
	my $partFound				= 0;

	for (my $i=0; $i <= $#arraysOfTermsHUGOIDs; $i+=2)
	{   if ($$ref[$flankingIndex] =~ /$arraysOfTermsHUGOIDs[$i]\b/)
		{	#  There is such overlapping
			$partFound = 1;
			last;
		}
	}
	return ($partFound);
}

sub SciMiner_CoExist_Score_Calculate
{   my ($sentence, $firstWordArray, $firstWordScoreHash) = @_;
    my $matchScore = 0;
    if (defined $firstWordArray)
    {   foreach (@{$firstWordArray})
        {   my $tmpKey = special_character_handling_for_hash_key($_);
            if ($$sentence =~ /\b$tmpKey\b/i)
            {   $matchScore += $$firstWordScoreHash{$_};
                ### TTT
                #print "> MATCH: $_\t$$firstWordScoreHash{$_}\t$matchScore\n";
            }
        }
    }
    return ($matchScore);
}


sub SciMiner_CoExist_Score_Calculate_With_Symbol
{   my ($sentence, $sentenceOriginal, $matchingTerm, 
		$firstWordArray, $firstWordScoreHash, $HUGO2AllSymbolRef, $hugoID) = @_;
    my $matchScore = 0;
    
    #  Name based co-exist score addition
    if (defined $firstWordArray)
    {   foreach (@{$firstWordArray})
        {   my $tmpKey = special_character_handling_for_hash_key($_);
            if ($$sentence =~ /\b$tmpKey\b/)
            {   $matchScore += $$firstWordScoreHash{$_};
            }
        }
    }
	
	#  Symbol based co-exist score addition
	#  The idea behind this is that if there are 
	foreach my $tmpSym (@{$$HUGO2AllSymbolRef{$hugoID}})
	{	#  Check for other symbol only the symbol is not same as the 
		#  current matching term.
		if ($matchingTerm ne $tmpSym)
		{   if ($$sentenceOriginal =~ /\b$tmpSym\b/)
			{   $matchScore += 0.5;
			}
		}
	}
    return ($matchScore);
}


sub Calculate_Flanking_Word_Score_For_Gene
{   my ($sentence, $geneSymbol) = @_;
    my $score = 0;
    
	# The following adds more score where the symbol is a few words behind the word 'gene(s)' or 'protein(s)'
	$$sentence =~ s/(\bgenes?(\S*\s?){0,3} $geneSymbol\b)/$score+=0.3;$1/eig;
	$$sentence =~ s/(\bproteins?(\S*\s?){0,3} $geneSymbol\b)/$score+=0.3;$1/eig;
	
	$$sentence =~ s/(\bgenes? $geneSymbol\b)/$score+=0.5;$1/eig;
    $$sentence =~ s/(\b$geneSymbol genes?\b)/$score+=0.5;$1/eig;
    $$sentence =~ s/(\bproteins? $geneSymbol\b)/$score+=0.5;$1/eig;
    $$sentence =~ s/(\b$geneSymbol proteins?\b)/$score+=0.5;$1/eig;
    $$sentence =~ s/(\bmRNAs? $geneSymbol\b)/$score+=0.5;$1/eig;
    $$sentence =~ s/(\b$geneSymbol mRNAs?\b)/$score+=0.5;$1/eig;
    
    
    # Previous
    #$$sentence =~ s/(\bgenes? $geneSymbol\b)/$score++;$1/eig;
    #$$sentence =~ s/(\b$geneSymbol genes?\b)/$score++;$1/eig;
    #$$sentence =~ s/(\bproteins? $geneSymbol\b)/$score++;$1/eig;
    #$$sentence =~ s/(\b$geneSymbol proteins?\b)/$score++;$1/eig;
    return ($score);
}


#  This checks a given string for any upper character or number
#  If such character found, return 1. If not, return 0
sub check_upper_number_char
{	my $string	= shift;

	if (($string ne "") && ( $string =~ /[A-Z]|\d/))
	{	return(1);
	}else
	{	return(0);
	}
}



sub SciMiner_check_exclusion_list_additional
{   my ($wholeTextContentRef, $pmid, $EXCLUDESYMBOLCOND) = @_;
    my $exclusionFound = 0;
    foreach my $excKey ( @{$EXCLUDESYMBOLCOND} )
    {   my $NewExcKey = special_character_handling_for_hash_key($excKey);
        if ($$wholeTextContentRef{$pmid} =~ /\b$NewExcKey/i)
        {   # If there is any EXCLUSION word(s) in the whole text
            $exclusionFound = 2;
            return ($exclusionFound, $NewExcKey);
        }
    }   #LogQuery("Exclusion was found $exclusionFound $NewExcKey\n");
    return ($exclusionFound);
}

sub SciMiner_check_inclusion_list_additional
{   my ($wholeTextContentRef, $pmid, $INCLUDESYMBOLCOND) = @_;
    my $inclusionFound = 0;
    foreach my $incKey ( @{$INCLUDESYMBOLCOND} )
    {   if ((defined $incKey) && ($incKey ne ""))
        {   my $NewIncKey = special_character_handling_for_hash_key($incKey);
            if ($$wholeTextContentRef{$pmid} =~ /$NewIncKey/i)
            {   # If there is any EXCLUSION word(s) in the whole text
                $inclusionFound = 1;
                return ($inclusionFound, $NewIncKey);
            }
        }
    }   return ($inclusionFound);
}




1;
