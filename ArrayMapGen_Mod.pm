package ArrayMapGen;
# Owner: Mohammad Fidaali 

# Function called from within fuse_xml_creation script.
# Objective: parse array_map.csv file to generate <fuseptr> code in XML and generate fuse address map CSV file for validation team. CSV file should specify the location of each fuse in the register file

my $glb_ref;
my %csv_hash=();
my %fuses_wo_info=();
my @sorted_csv;

sub gen_array_map
{
  # Arguments
  # $model should be "fc"
  # $fh is the fuseptr file handle (or {PROJ}_fuse_creg.xml)
  # $fuses_ref is a REFERENCE to hash, storing all the fuse instances in terms of field granularity.
  # Structure:
  #     $fuses_ref->{ <fuse name> }{ CHAIN }         => refers to the chain this instance belongs to 
  #     $fuses_ref->{ <fuse name> }{ SUBCHAIN }      => refers to the leaf subchain in the chain
  #     $fuses_ref->{ <fuse name> }{ BIT }           => refers to the bit in the leaf subchain
  #     $fuses_ref->{ <fuse name> }{ CHN_INSTANCE }  => refers to the name of the chain instance. If there is no chain instance, then this would be the name of the chain.
  # NOTE: bit is equivalent to field
  #
  # $defines is a data structure that you may not need at all, I think. If you do need it, I can show you how to use it.

  my ($model, $fuses_ref, $defines_ref, $debug) = @_;
  my %fuses_hash=%$fuses_ref;
  $glb_ref=\%fuses_hash;

  my $file_name   = "$ENV{PROJECT}_fuse_creg.xml";
  my $output_path = "$ENV{MODEL_ROOT}/some_path";  
  open my $xml_out,  '+>', "$output_path/$file_name" or die "[-E-]: Cannot open $output_path/$file_name for writing\n";
  my $printout_xml   = "";  
  &print_xml_header($xml_out);

  if($debug)
  {
    foreach my $fuse_name (keys %$glb_ref)
    {
      print "[-D-]: Fuse in GLB_REF: $fuse_name\n";
    }
  }

  # The format should be...         <fuse name>:<address>
  # Address should be the location of the fuse when in a 1D array.
  #     Ex. Row 1, Column 0  => address = 64

  #         - Parse CSV file and store information (one function)
  #             - Storing your data allows you to easily modify code.
  #             - I would recommend using hashes since the amount of information you need to store should be minimal
  #         - Generate <fuseptr> code accordingly (one function)
  #         - Separating parsing and generation make code cleaner and more readable
  
  my $input_file_name   = "array_map.csv";
  my $input_path = "{Some_path_to_fuses}fuse_blocks/src";

  open my $store_csv_file, "<", "$input_path/$input_file_name" or die "[-E-]: Cannot open $input_path/$input_file_name for storing in hash\n";
  &store_old_array_map_csv($store_csv_file);
  close $store_csv_file;

  open my $populate_csv_file, ">", "$input_path/$input_file_name" or die "[-E-]: Cannot open $input_path/$input_file_name for populating new csv file\n";
  &populate_array_map_csv($populate_csv_file, $defines_ref);
  close $populate_csv_file;

  open my $read_csv_file, "<", "$input_path/$input_file_name" or die "[-E-]: Cannot open $input_path/$input_file_name for reading newly created csv file\n";
  &print_xml_fuse_address($xml_out, $read_csv_file);
  close $read_csv_file;

  # Finalize fuse XML.
  $printout_xml .= "  </chain>\n";
  $printout_xml .= "</chip>\n";

  print $xml_out $printout_xml;
  close $xml_out; 
}
#################
# Populate new csv file #
#################
sub populate_array_map_csv
{
    print "\n\n";
    my ($csv, $defines) = @_;
    my $first = 1;
    my @empty_positions;
    my $err=0;
    my $row=0;
    my $column=0;

    my $bit_length;    
    print $csv "FUSENAME,POSITION,PADDING_LENGTH,ROW,COLUMN\n";
    # Look for new fuses, which will be printed at the very bottom of CSV file.
    foreach my $fuse_name (keys %$glb_ref)
    {
        if (!defined $csv_hash{$fuse_name}) 
        {
            $fuses_wo_info{$fuse_name}=1;
        }
    }

    # Generate the old fuses in order of POSITION, automatically calculating the ROW and COLUMN
    for (my $i=1; $i< scalar @sorted_csv; $i++)
    {
        if (defined $sorted_csv[$i])
        {
            print $csv "$sorted_csv[$i],$csv_hash{$sorted_csv[$i]}{POSITION},$csv_hash{$sorted_csv[$i]}{PADDING_LENGTH},$row,$column,";
            if ($sorted_csv[$i]=~/padding/i)
            {
                $column+=$csv_hash{$sorted_csv[$i]}{PADDING_LENGTH};
                print $csv "$csv_hash{$sorted_csv[$i]}{PADDING_LENGTH}\n";
            }
            else
            {
                my $subchain_name;
                my $subchain;
                my @bit_list;
                my @bit_length_arr;
                $subchain_name=$glb_ref->{$sorted_csv[$i]}{SUBCHAIN};
                $subchain=$defines->{subchain}{$subchain_name};
                @bit_list=$subchain->get_bits();
                foreach my $bit (@bit_list)
                {
                    if ($bit->get_name eq $glb_ref->{$sorted_csv[$i]}{BIT})
                    {
                        @bit_length_arr= $bit->get_attribute("length");
                        $bit_length=$bit_length_arr[0];
                        last;
                    }
                }
                print $csv "$bit_length\n";
                $column+=$bit_length;
            }
            while($column>=64)
            {
                my $prev_row=$row;
                $row++;
                $column=$column-64;
                print "[-I-]: Fuse [$sorted_csv[$i]] is wrapped around from row $prev_row to row $row\n" if($column != 0);
            }
            if ($row>127)
            {
                die "\n\n\n[-E-]: You have surpassed allotted space for fuses!\n\n\n";
            }
        }
        else
        {
            push (@empty_positions, "$i");
            $err=1;
        }
    }

    # Print new fuses.
    foreach my $fuse_name (sort keys %fuses_wo_info)
    {
       print $csv "$fuse_name,,,,\n"; 
    }
 
    if ($err)
    {
        die "[-E-] The following position numbers have no fuses associated with them, probably because of deleted fuses:\n\n@empty_positions\n\nPlease update the csv list with position values and rerun script.\n";
    }
}
#################
# Store old csv in hash #
#################
sub store_old_array_map_csv
{
    my ($csv) = @_;
    my $first = 1;
    my $line_num=0;
    my $err=0;
    while (my $line=<$csv>)
    {
        $line_num++;
        if ($first)
        {
## header check 
            my @header_check= split(',', $line);            
            if (($header_check[0] ne "FUSENAME") || ($header_check[1] ne "POSITION") || ($header_check[2] ne "PADDING_LENGTH")) 
            {
                die "[-E-] CSV file has incorrect headers. Please correct them\n1st column header= \"FUSENAME\"\n2nd column header= \"POSITION\"\n3rd column header= \"PADDING_LENGTH\"\n";                
            }
            else
            {
                $line= <$csv>;
                $first=0;
            }
        }
        if ($first==0)
        {
            $line=~ s/\s+$//;
            chomp ($line);
            my @fuse_headers= split(',', $line);

            $fuse_headers[0]=~ s/\s+$//;  # extra space, remove it
            $fuse_headers[1]=~ s/\s+$//;  # extra space, remove it
            $fuse_headers[2]=~ s/\s+$//;  # extra space, remove it
            my $fusename= $fuse_headers[0];
            my $position= $fuse_headers[1];
            my $padding_length= $fuse_headers[2];
            if ($fusename=~/padding/i)
            {
                $glb_ref->{$fusename}=1;
            }

            # In case of fuses that are removed 
            if (defined $glb_ref->{$fusename})
            {
                $csv_hash{$fusename}{POSITION}=$position;
                $csv_hash{$fusename}{PADDING_LENGTH}=$padding_length;
                if(defined $position) {
                    $sorted_csv[$position]=$fusename;
                }
                else {
                    $fuses_wo_info{$fusename}=1;
                }
            }
        }   
    }
}

##############
# print XML Address in proj_fuse_creg.xml#
##############
sub print_xml_fuse_address
{
    my ($file, $csv) = @_;
    my $first = 1;
    my $line_num=0;
    while (my $line=<$csv>)
    {
        $line_num++;
        if ($first)
        {
            $line= <$csv>;
            $first=0;
            
        }
## if headers in csv file are correct
        $line=~ s/\s+$//;
        chomp ($line);
        my @fuse_headers= split(',', $line);
        $fuse_headers[0]=~ s/\s+$//;  # remove extra spaces
        $fuse_headers[1]=~ s/\s+$//;  # extra space, remove it
        $fuse_headers[2]=~ s/\s+$//;  # extra space, remove it
        my $fusename=$fuse_headers[0];
        my $position= $fuse_headers[1];
        my $padding_length= $fuse_headers[2];
## Check if fuse actually exists in hash
        if ($fusename=~ /padding/i)
        {
            print $file "<fusebit name=\"$fusename\" owner=\"\" class=\"\">\n\t<length>$padding_length</length>\n\t<description>Padding:$padding_length bits</description>\n\t<access_type>RO</access_type>\n\t<fuse_program_value type=\"default\">${padding_length}'h0</fuse_program_value>\n\t<fuse_program_lock>none</fuse_program_lock>\n</fusebit>\n\n";
            
        }
        elsif(defined $position)
        {
            my $concat_fuse= $fusename;
            $concat_fuse=~ s/(^.*?)(?=_)//;
            $concat_fuse=~ s/^.//;
            if ($glb_ref->{$fusename}{CHN_INSTANCE} eq $glb_ref->{$fusename}{CHAIN})
            {
                print $file "<fuseptr bus=\"fuselink\"  name=\"$concat_fuse\" owner=\"\" class=\"\">\n\t<access_type>RW</access_type>\n\t<fuse_program_lock>none</fuse_program_lock>\n</fuseptr>\n\n";
                
            }
            else
            {
                print $file "<fuseptr bus=\"fuselink\" register=\"$glb_ref->{$fusename}{CHN_INSTANCE}\"  name=\"$concat_fuse\" owner=\"\" class=\"\">\n\t<access_type>RW</access_type>\n\t<fuse_program_lock>none</fuse_program_lock>\n</fuseptr>\n\n";
            }
        }
        
    }
    print "***********************\n";
    print "****** COMPLETE *******\n";
    print "***********************\n";
}


##############
# XML Header #
##############

sub print_xml_header
{
  my $fh = shift;

  print $fh <<HEADER;
<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE chip PUBLIC "PUBLIC" "bus_info.dtd">
<chip>
        <alignment>64</alignment>
HEADER
}


1; # successfully loaded
