#!/usr/bin/perl

use strict;
use warnings;

#use HTML::Parser;
use HTML::TreeBuilder;
use XML::LibXML;
use File::Slurp;
use Data::Dumper;
my $dir= "./orders/";
my @files= read_dir($dir);
my $parser = XML::LibXML->new();
foreach my $file (@files)
#my $file = $files[0];
{
    my $eml = read_file($dir.$file);
    #Remove all MIME Encoding/Mac Mail Encoding
    $eml =~ s/(.|\n)*X-Scanned-By:.*?$//m;
    $eml =~ s/=0D=0A//g;
    $eml =~ s/=3D/=/g;
    $eml =~ s/=20//g;
    $eml =~ s/=\s*?$//mg;
    $eml =~ s/\cM//g;

    #nbsp is breaking the xml parser
    $eml =~ s/&nbsp;//g;
    
    my $html = HTML::TreeBuilder->new_from_content( "<html>". $eml ."</html>" );
    my $xml = $html->as_XML();
    
    #XML::LibXML Document
    my $doc = $parser->parse_string($xml);
    
    #OrderID is consistently placed Across all documents
    my $order_id = $doc->findvalue('./html/body/table/tbody/tr[3]/td[3]');
    #print "Order ID: $order_id\n";
    #EmailADDR is consistently placed Across all documents
    my $email_addr = $doc->findvalue('./html/body/table/tbody/tr[16]/td[3]');
    #print "Email: $email_addr\n";

    #Find the TR for the "Products Ordered TR"
    my @nodes= $doc->findnodes('//td[text()="Products Ordered "]');
    #warn $doc->exists('//td[text()="Products Ordered "]');
    foreach my $node (@nodes){
	#warn "found";
	#warn Dumper $node;
	#Traverse from the next TR into the nested tables which contain the actual orders
	my @tables = $node->findnodes('../following-sibling::tr/td/table/tbody/tr/td/table');
	#warn $node->exists('//tr/td/table//table');
	my $table = $tables[0];
	{
	    #warn $table->toString(1);
	    #job number is consistently placed within this table
	    my $job_number = $table->findvalue('./tr[2]/td[1]');
	    
	    #rows with 6 columns are orders, less than that and they're the summary information
	    my @rows = $table->findnodes('./tr[td[6]]');

	    foreach my $row (@rows){
		#warn $row->toString(1);
		#Address is the 3rd row, Type the 4th, Job Name the 2nd
		my @addresses = $row->findnodes('td[3]');
		my $type = $row->findvalue('td[4]');
		my $job_name = $row->findvalue('td[2]');
		foreach my $address (@addresses){
		    
		    my $text = $address->textContent();
		    #First Row is header, and we don't need it.
		    if( $text =~ /^Address$/ ){ 
			next; 
		    }

                    #Address has <br/> added to it, they get stripped in textContent(), so get whole TD as a string and replace br with spaces.
		    my $addr_string = $address->toString(1);
		    $addr_string =~ s/\<\/?td\/?\>//g;
		    
		    
                    # Name is always the first line of the address.
		    my ($name)= $addr_string =~ /(.*?)<br\/>/;
		    trim(\$name);
		    my $br = quotemeta("<br/>");
		    $addr_string =~ s/$br/ /g;
		    #output in semicolon delimited format, because addresses have commas.
		    print "$name; $email_addr; $job_name; $order_id; $addr_string\n";

		}
	    }
	}

    }
    #print "\n\n";
}

sub trim {
    #Assumed I'd need to use this more than I did.
    my $val = shift;
    $val =~ s/^\s+//;
    $val =~ s/\s+$//;
    return ($val);
}
