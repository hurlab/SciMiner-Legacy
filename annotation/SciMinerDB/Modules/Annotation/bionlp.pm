#
# Perl module for natural language processing in XML
#
package bionlp;

BEGIN {
#
# Document divisions
# NOSECTION has been added by Junguk (02/20/2008)
	%Divisions = (DOC => -1, PMID => 1, TITLE => 2, AUTHORS => 3, 
		ABSTRACT => 4, INTRODUCTION => 5, 
		METHODS => 6, RESULTS => 7, 
		DISCUSSION => 8, ACKNOWLEDGMENTS => 9, 
		ABBREVIATIONS => 10, FOOTNOTES => 11, 
		REFERENCES => 12, FIGURES => 13, 
		TABLES => 14,
		UNKNOWN => 15, NOSECTION => 16
	);
#
# Tag mappings for output
#
	%BlockTag = (
# Sentence
		s => 's',
# Paragraphs
		p => 'p',
		bq => 'p',
		center => 'p',
		div => 'p',
		pre => 'p',
		address => 'p',
		form => 'p',
		code => 'p',
		samp => 'p',
# Heading paragraphs
		h1 => 'heading',
		h2 => 'heading',
		h3 => 'heading',
		h4 => 'heading',
		h5 => 'heading',
		h6 => 'heading',
# Containers
		table => 'table',
		tr => 'tr',
		ol => 'ol',
		ul => 'ol',
		dl => 'ol',
		dir => 'ol',
		menu => 'ol',
# Cells
		td => 'td',
		th => 'td',
		li => 'li',
		dt => 'li'
	);
}

sub Template {
	my $self = shift;

	my $str = "<DOC>\n";
	foreach my $div (sort {$Divisions{$a} <=> $Divisions{$b};} keys %Divisions) {
		if ($Divisions{$div} > 0) {
			$str .= "<$div/>\n";
		}
	}
	$str .= "</DOC>\n";
	return $str;
}

sub ReplaceInlineImages {
	my $self = shift;
	my $xp = shift;
	my $nodeset = $xp->find("//img");
	my @node = $nodeset->get_nodelist();
	foreach my $node (@node) {
		my $alt = $node->getAttribute("alt");
		my $symbols = "dagger|ddagger|Dagger|Ddagger|square|blacksquare|approx|~|-|->|<-|<=|>=|".
			"alpha|beta|gamma|delta|epsilon|zeta|eta|theta|iota|kappa|lambda|mu|nu|xi|omicron|pi|rho|sigma|tau|upsilon|phi|chi|psi|omega|".
			"Alpha|Beta|Gamma|Delta|Epsilon|Zeta|Eta|Theta|Iota|Kappa|Lambda|Mu|Nu|Xi|Omicron|Pi|Rho|Sigma|Tau|Upsilon|Phi|Chi|Psi|Omega";
		if ($alt =~ /^[ \{]*(var)?($symbols)[ \}]*$/) {
			my $text = $2;
			$text =~ s/approx/~/;
			my $textnode = new XML::XPath::Node::Text($text);
			if ($DBG) { print STDERR "Replacing $node with $textnode\n"; }
			my $parent = $node->getParentNode();
			$parent->insertBefore($textnode,$node);
			$parent->removeChild($node);
		} else {
			if ($alt && $alt !~ /^ *$/) {
				print STDERR "Unmatched alternate image >$alt<\n";
			}
		}
	}
}

#
# Some extensions to XML::XPath
# toText strips out extraneous HTML tags
#
package XML::XPath::Node::ElementImpl;

use vars qw/@ISA/;
@ISA = ('XML::XPath::NodeImpl', 'XML::XPath::Node::Element');
use XML::XPath::Node ':node_keys';

sub toText {
	my $self = shift;
	my $norecurse = shift;
	my $string = '';
	my $nm = $self->[node_name];

	if (! $nm ) {
		# root node
		return join('', map { $_->toText($norecurse) } @{$self->[node_children]});
	}

	if ($nm =~ /^(br|hr)$/i) {
		$string .= "\n<".$nm."/>\n";
	}

	if ($nm =~ /sub|sup/) {
		$string .= "{" . $nm."_";
	}

	if ($bionlp::Divisions{$nm} || $bionlp::BlockTag{$nm}) {
		if ($bionlp::BlockTag{$nm}) {
			$string .= "\n<" . $bionlp::BlockTag{$nm};
		} else {
			$string .= "\n<" . $nm;
		}
		$string .= join('', map { $_->toString } @{$self->[node_namespaces]});
		$string .= join('', map { $_->toString } @{$self->[node_attribs]});
		$string .= ">\n";
	}

	if (@{$self->[node_children]}  && !$norecurse) {
		foreach my $node (@{$self->[node_children]}) {
			if ($node->getNodeType() == ELEMENT_NODE || $node->getNodeType() == TEXT_NODE) {
				$string .= $node->toText($norecurse);
			}
		}
	}

	if ($nm =~ /sub|sup/) {
		$string .= "}";
	}
	if ($bionlp::Divisions{$nm}) {
		$string .= "\n</" . $nm . ">\n";
	}
	if ($bionlp::BlockTag{$nm}) {
		$string .= "\n</" . $bionlp::BlockTag{$nm} .">\n";;
	}

	return $string;
}

package XML::XPath::Node::TextImpl;

use vars qw/@ISA/;
@ISA = ('XML::XPath::NodeImpl', 'XML::XPath::Node::Text');
use XML::XPath::Node ':node_keys';

sub toText {
    my $self = shift;
	my $str = $self->[node_text];
	$str = XML::XPath::Node::XMLescape($str, "<&");
	$str =~ s/([\x80-\xff])/XMLencode($1)/ges;
	$str =~ s/[\x00-\x1f]+/ /g;
	$str =~ s/ +/ /g;
	$str;
}

package XML::XPath::Node::ElementImpl;

sub Path {
	my $self = shift;
	my $str = $self->getName();
	if (my $pnode = $self->getParentNode()) {
		$str = $pnode->Path().'/'.$str;
	}
	return $str;
}

1;
