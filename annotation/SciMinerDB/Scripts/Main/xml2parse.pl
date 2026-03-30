#!/usr/bin/perl
#
# Read XML and analyze text blocks
# <p> <td>
#
BEGIN {push (@INC, "/home/hurlab/apache-tomcat-9.0.37/webapps/SciMiner1.1/annotation/SciMinerDB/Modules/Annotation/");}

#use lib "/home/sciminer/simplepipeline/lib";
use XML::XPath;
use XML::XPath::XMLParser;
use XML::XPath::Node ':node_keys';
use bionlp;







#
# Setup the root of the output tree
#
$build = new XML::XPath(xml => bionlp->Template());
$bset = $build->find("/DOC");
($bnode) = $bset->get_nodelist();

# Global paragraph counter
$PPN = 0;


my $xp = new XML::XPath(filename => $ARGV[0]);
my $dset = $xp->find("/DOC");
my ($dnode) = $dset->get_nodelist();
TraverseTree($dnode);
#
# Print the result
#
$bset = $build->find("/DOC");
($bnode) = $bset->get_nodelist();
open (OUTFILE, ">".$ARGV[1]);
print OUTFILE $bnode->toText();
close OUTFILE;
#
# Cleanup
#
$xp->cleanup();





sub TraverseTree {
	my ($node) = shift;

	if ($DBG) { print STDERR "TraverseTree: $node\n"; }
	if (!defined $node) { print STDERR "Traverse called on null\n";}

	foreach my $child ($node->getChildNodes()) {
		if ($child->getNodeType() == XML::XPath::Node::ELEMENT_NODE) {
			my $tag = $child->getName();
			if ($bionlp::Divisions{$tag}) {
				$bset = $build->find("//$tag");
				($bnode) = $bset->get_nodelist();
				TraverseTree($child);
				next;
			}
			if ($bionlp::BlockTag{$tag} eq 'p') {
				ProcessParagraph($child);
				next;
			}
			TraverseTree($child);
		} elsif ($child->getNodeType() == XML::XPath::Node::TEXT_NODE) {
			ProcessParagraph($child);
		} else {
			print STDERR "Child type: ",$child->getNodeType(),"\n";
		}
	}
}

sub ProcessParagraph {
	my($node) = shift;

	#
	# Get the text for this paragraph
	# Strip <p> tags and terminal spaces
	#
	my $str = $node->toString();
	$str =~ s!<.*?>(.*)</.*?>!$1!s;
	$str =~ s!<br */>!$1!gs;
	$str =~s/^\s*(.*)\s*$/$1/s;
	if ($str =~ /^\s*$/s) { return; }

	#
	# Bug in sentence splitter, remove periods fb blanks inside parens
	#
	while ($str =~ /\(([^)]*)\. ([^)]*)\)/) {
		$str =~ s/\(([^)]*)\. ([^)]*)\)/($1 $2)/g;
	}

	#
	# Add a paragraph node and its text to the output
	#
	my($pout) = new XML::XPath::Node::Element('p');
	$bnode->appendChild($pout);
	my $anode = new XML::XPath::Node::Attribute('ppn',++$PPN);
	$pout->appendAttribute($anode);
	my $tnode = new XML::XPath::Node::Text($str);
	$pout->appendChild($tnode);
}
