#!/usr/intel/bin/perl -w
#* -------------------------------------------------------------------
#* Filename: check_rtl_sva_density_sip_xml.pl                             
#* Owner: Fidaali, Mohammad 
#* Date: 2015-02-19 
#* Description: 
#* This script will check the amount of coverage/assertions in RTL per partition block. Will give exact number of lines of coverage 
#* as well as total number of RTL lines per partition. SIP blocks are currently supported
#*
#* To see the displayed information, please visit
#*
#*
#* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

# STANDARD PROJECT HEADER {{{
#* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
# This section is executed as soon as possible, ie before the rest of the containing file is parsed.
# This is required to include roject specific library paths
#* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
BEGIN { 
   # Check if the environment variable $PROJ_UTILS is defined.
   if (!($PROJ_UTILS = "$ENV{'PROJ_UTILS'}")) {
      print "Something is wrong with your setup:  \$PROJ_UTILS is not defined.\n\n";
      exit 1;
   }
   # Tell PERL where to look for Perl script (.pl) ,include file (.ph), or module file (.pm) 
   # Then, you can 'require', 'use' the file without specifying the whole path
   unshift @INC , "$PROJ_UTILS/include/perl";
}
#use XML::LibXML;
use XML::Simple;
#use XML::Dumper;
#use XML::Twig; 
use strict;
use vars qw($date $curdir $scroot $hostname @options %Opts $help_flag 
            $scname $scpath $scspcs $usage_errors $version @usage $repo_base $log_dir 
            $glb $chn $msc $all $partition $fr $connit $goal $comment_flag $flag
            $date_dir $call $flag $fnvio_flag $block_name $make_call $make_status $coverage_total $assert_count 
            $cover_count $skip $IN $final_path %top $path_key $value %block_key
            $rtl_total $divisor $percent $divisor_trunc
            $first_key $block_key $final_key $path_cover_count %block_sum
            $xml_output $xs $main $revised_date $reed_solomon $sip);

#*************************
# Use built-in package ***
#*************************
use Cwd;             # Get pathname of current working directory
use English;         # Use English names for punctuation variables; 
use File::Basename;  # Parse file specifications

#*************************************
# Include the PROJECT include file ***
#*************************************

$OUTPUT_AUTOFLUSH = 1;  # tell the current file handle (STDOUT) not to buffer.

#************************
# Some basic captures ***
#************************
$curdir = cwd();           #current working directory capture
chop ($hostname = `hostname`);
chop ($date = `date`);     #capture the start date

# Gather the info for the script path, the script name, and the root of the script name. 
# The $scroot variable can be used for creating log files (i.e. $scroot.log rather than $scname.log)

($scpath,$scname) = $PROGRAM_NAME =~ /(.*)\/([^\/]+)/;
if (!$scpath) {                         # If there was no scpath set, assume
    $scpath = ".";                      # there was no "/" in the command,
    $scname = $PROGRAM_NAME;            # meaning it was fired from $cwd. If
}                                       # so, set $scpath to "."
($scroot = $scname) =~ s/\.[^.]*$//g;   # Get the root of the script name.
$scspcs = " " x length($scname);


#*********************************
#*** Prepare the usage string. ***
#*********************************

&prepare_usage();     # usage help screen if user requests help -h/-help 

$help_flag = 0;

# standard command line processing
use Getopt::Long ();
Getopt::Long::Configure('default');
die if !Getopt::Long::GetOptions(
        #'testname=s'            => \$Opts{testname},
        'g'                   => \$glb,
        'c'                   => \$chn,
        'm'                   => \$msc,
        's'                   => \$sip,
        'help'                => \$help_flag
    );

$usage_errors .= "Error: -partition selection is required\n" unless( $glb || $chn || $msc || $sip || $help_flag);
if ( $usage_errors ) {
    print "\n$usage_errors\n";
    print @usage;
    exit(1);
}

if ( $help_flag ) {
    print @usage ;
    exit(0);
}

# }}}


#*****************************
#*** BASICS ***
#*****************************
$repo_base = `git rev-parse --show-toplevel`; # use git to get the path to the repo base
chomp ($repo_base); # remove newline char
#print "$repo_base\n";
#print "$scpath\n";
#print "$scname\n";


#*****************************
#*** Place the main coding ***
#*****************************
my %top=();
#my $dump=new XML::Dumper;
=comment
if($glb) {
&glb;
&start;
}

if($chn) {
&chn;
&start;
}

if($msc) {
&msc;
&start;
}
=cut


if($sip) {
&reed_solomon;
&sip_start;
undef %top;

&ecc_rf_ram_cam;
&sip_start;
undef %top;

&security_eau;
&sip_start;
undef %top;

}


#***********************************
#*** Place the subroutines here  ***
#***********************************
=comment
sub glb {

    $partition= "glb";
    $fr= "${repo_base}/rtl/glb/ace/_glb_dut.fr";

}

sub chn {

    $partition= "chn";
    $fr= "${repo_base}/rtl/chn/ace/_chn_dut.fr";

}

sub msc {

    $partition= "msc";
    $fr= "${repo_base}/rtl/msc/ace/_msc.fr";

}
=cut
sub reed_solomon {

    $partition= "reed_solomon";
    $fr= "${repo_base}/rtl/common/_collateral/reed_solomon/sva_reed_solomon.fr";

}
sub ecc_rf_ram_cam
{
    $partition= "ecc_rf_ram_cam";
    $fr= "${repo_base}/rtl/common/_collateral/secded/sva_secded.fr"
}
sub security_eau
{
    $partition= "security_eau";
    $fr= "${repo_base}/rtl/msc/sunit/s_eau/eau_top/eau_top.fr";
}
=comment
$fr= "${repo_base}/ ";
$fr= "${repo_base}/ ";
$fr= "${repo_base}/ ";
$fr= "${repo_base}/ ";
$fr= "${repo_base}/ ";
$fr= "${repo_base}/ ";
$fr= "${repo_base}/ ";
$fr= "${repo_base}/ ";
$fr= "${repo_base}/ ";
$fr= "${repo_base}/ ";
$fr= "${repo_base}/ ";
=cut
sub sip_start {

#$log_dir= "$repo_base/rtl/tools/check_coverage"; #UNCOMMENT
$log_dir= "/nfs/cl/disks/wdisk.150/mfidaali/scripts/sva_density_sip/"; #REMOVE
mkdir $log_dir, 0750 || die "Coudln't mkdir" unless -d $log_dir;

################################################
#Creating latest/date directories for website
################################################

my $date= `date +v%Y_%m_%d`;
chomp $date;

my $date_dir= "/p/web/udocs/sva_density/".$date;
mkdir $date_dir, 0750 || die "Coudln't mkdir" unless -d $date_dir;
#print "$date_dir";
chdir "/p/web/udocs/sva_density/";
unlink "latest";
symlink ($date, "latest");
`cp /p/web/udocs/sva_density/_sva.css $date_dir`;
`cp /p/web/udocs/sva_density/sva_density.xsl $date_dir`;

my $revised_date= `date +%Y/%m/%d`;
chomp $revised_date;
#print $revised_date;

open(IN, '>', "$log_dir/${partition}_flatten_paths.txt") || die "cannot open file";
print IN `flatten_fr -f $fr`;
close IN;

open(IN, '<', "$log_dir/${partition}_flatten_paths.txt") || die "cannot open txt";
open(PARSE,'>',"$log_dir/${partition}_parse.log") || die "cannot write to log"; 
open(CONN,'>',"$log_dir/${partition}_conn.log") || die "cannot write to log";
open(KEYS_RTL,'>',"$log_dir/${partition}_hash.log") || die "cannot write to log"; 
#open(KEYS,'>',"$date_dir/${partition}_hash.xml") || die "cannot write to log";  
open(KEYS,'>',"$log_dir/${partition}_hash.xml") || die "cannot write to log"; #REMOVE
open(NP,'>',"$log_dir/${partition}_not_parsed.log") || die "cannot write to log";


#open(FILE_LOG,'>',"$date_dir/${partition}_info.txt") || die "cannot write to log";
open(FILE_LOG,'>',"$log_dir/${partition}_info.txt") || die "cannot write to log";#REMOVE
=comment
open(FILE_LOG,'>',"$log_dir/${partition}_info.txt") || die "cannot write to log";
=cut

############################################
# Start Actual Computation code
############################################

my $cover_count=0;
my $assert_count=0;
my $coverage_total=0;
my $rtl_total=0;
my $comment_flag; 
my $flag;
my $block;
my $final_path;
my $main;

while(<IN>)
{
################################################
# obtain each RTL path for partition
################################################
   chomp ($_);   
   my $path= $_;
   
################################################
# Open each path file that follows .v, .vs, .sv format
################################################
   if((($path=~ /.vs$/) || ($path=~ /.sv$/) || ($path=~ /.v$/)) && $path!~/soc_macros.sv/ && $path!~/\/ace\// && $path!~ /fuse_macros.sv/ && $path!~ /iot_macros.sv/ && $path!~ /mbist_LV_MACROS.v/ && $path!~ /iscan_macros.sv/ )
   { 
################################################
# Open each path file that is NOT generated by connit
################################################
       $connit=`grep -qi "generated by: connit" $path`;
       $make_status= $? >> 8;
       if ($make_status) #Not generated by connit
       {
           print PARSE $path;
           print PARSE "\n";
################################################
# Find block name and final path name pending if its common/glb/chn/msc/etc
################################################
#           print KEYS $path;
#           print KEYS "\n";
#           if($path=~/\/glb\//)
#           {
               $main=$partition;
               $final_path= $path;
               $final_path=~ s/(.*\/)//g;
               $block= $path;
               $block=~ s/(^.*?)(?=\/$partition\/)//;
               my $length= length($partition);
               my $add_len =$length+2;
           for (my $i=0; $i <$add_len; $i++)
           {
               $block=~ s/^.//;
           }
               $block=~ s/\/.*//;
#                print KEYS "$block\n";
#                print KEYS "$final_path\n";
               
#           } 
=comment
           if($path=~/\/common\//)
           {
               $main="common";
               $final_path= $path;
               $final_path=~ s/(.*\/)//g;
               $block= $path;
               $block=~ s/(^.*?)(?=\/common\/)//;
               $block=~ s/^........//;
               $block=~ s/\/.*//;
#                print KEYS "$block\n";
#                print KEYS "$final_path\n";
           }
           if($path=~/\/chn\//)
           {
               $main="chn";
               $final_path= $path;
               $final_path=~ s/(.*\/)//g;
               $block= $path;
               $block=~ s/(^.*?)(?=\/chn\/)//;
               $block=~ s/^.....//;
               $block=~ s/\/.*//;
#                print KEYS "$block\n";
#                print KEYS "$final_path\n";
           }
           if($path=~/\/msc\//)
           {
               $main="msc";
               $final_path= $path;
               $final_path=~ s/(.*\/)//g;

               $block= $path;
               $block=~ s/(^.*?)(?=\/msc\/)//;
               $block=~ s/^.....//;
               $block=~ s/\/.*//;
#                print KEYS "$block\n";
#                print KEYS "$final_path\n";
           }
=cut          
           my $path_rtl_count=0;

           my $path_assert_count=0;
           my $path_assert_percentage=0;
           my $path_assert_divisor_trunc=0;
           my $path_assert_percent=0;

           my $path_cover_count=0;
           my $path_cover_percentage=0;
           my $path_cover_divisor_trunc=0;
           my $path_cover_percent=0;

           my $path_coverage_count=0;
           my $path_percentage= 0;
           my $path_divisor_trunc=0;
           my $path_percent=0;

           open (RTL_path, '<', "$path") || die "cannot open RTL_path";
           $flag=0;
           $comment_flag=0;
           while (<RTL_path>)
           {
               my $line=$_;
################################################
# Turn on flag (and start counting lines) if we have reached module instantiation within file
# Dont count lines that are in comment block, commented out, or are blank
################################################
               if ($line=~ /module/)
               {
                   $flag=1
               }
               if ($flag==1 && $comment_flag==0 && ($line!~ /^\s*$/) && ($line!~ /^\s*\/\//))
               {
                   $rtl_total++;
                   $path_rtl_count++;
               }
               
################################################
#Check to see if coverage may be inside of a commented out section (do not include these lines of coverage in count)
################################################
               if (($line=~ /\/\*/) && ($line!~ /^\s*\/\//))
               {
                   $comment_flag=1;
               }
               if (($line=~ /\*\//) && ($line!~ /^\s*\/\//))
               {
                   $comment_flag=0;
               }
################################################
#Start counting number of lines of coverage
################################################
               if (($line=~ /`COVERS/) && ($line!~ /^\s*\/\//) && $comment_flag==0) 
               {
                   print CONN " $path";
                   print CONN "\n";
                   print CONN $line;
                   print CONN "\n";                   
                   $cover_count++;
                   $path_cover_count++;
               }
               if (($line=~ /`ASSERT/) && ($line!~ /^\s*\/\//) && $comment_flag==0) 
               {
                   print CONN " $path";
                   print CONN "\n";
                   print CONN $line;
                   print CONN "\n";
                   $assert_count++;
                   $path_assert_count++;
                   
               }
               
           } #end while
#           print "$path_rtl_count ";
#           print "$rtl_total\n";
=comment           
           my $path_assert_count=0;
           my $path_assert_percentage=0;
           my $path_assert_divisor_trunc=0;
           my $path_assert_percent=0;

           my $path_cover_count=0;
           my $path_cover_percentage=0;
           my $path_cover_divisor_trunc=0;
           my $path_cover_percent=0; 
=cut
           if ($path_assert_count==0)
           {
               $path_assert_percent=0;
           }
           else
           {
               $path_assert_percentage= $path_assert_count/$path_rtl_count;
               $path_assert_divisor_trunc= sprintf("%.2f",$path_assert_percentage*100); 
               $path_assert_percent= $path_assert_divisor_trunc;
           }
           
           if ($path_cover_count==0)
           {
               $path_cover_percent=0;
           }
           else
           {
               $path_cover_percentage= $path_cover_count/$path_rtl_count;
               $path_cover_divisor_trunc= sprintf("%.2f",$path_cover_percentage*100); 
               $path_cover_percent= $path_cover_divisor_trunc;
           }

           $path_coverage_count = $path_assert_count + $path_cover_count;
           if ($path_coverage_count==0)
           {
               $path_percent=0;
           }
           else
           {
               $path_percentage= $path_coverage_count/$path_rtl_count;
               $path_divisor_trunc= sprintf("%.2f",$path_percentage*100); 
               $path_percent= $path_divisor_trunc;
           }
           
           #Obtain number of coverage lines 
           push ( @{$top{$main}{$block}{$final_path}} , $path_percent );
       
           #Obtain number of coverage lines 
           push ( @{$top{$main}{$block}{$final_path}} , $path_coverage_count );

           #Test- Obtain number of total lines
           push ( @{$top{$main}{$block}{$final_path}} , $path_rtl_count );

           push ( @{$top{$main}{$block}{$final_path}} , $path_assert_count );
           push ( @{$top{$main}{$block}{$final_path}} , $path_assert_percent );

           push ( @{$top{$main}{$block}{$final_path}} , $path_cover_count );
           push ( @{$top{$main}{$block}{$final_path}} , $path_cover_percent );

       }  
       else
       {
           print NP "$path\n";

       }

   }
   else
   {
       print NP "$path\n";
   }

}
$coverage_total= $cover_count + $assert_count;
my $divisor= $coverage_total/$rtl_total;
my $divisor_trunc= sprintf("%.2f",$divisor*100); 
my $percent= $divisor_trunc;

my $cover_divisor = $cover_count/$rtl_total;
my $cover_divisor_trunc= sprintf("%.2f",$cover_divisor*100); 
my $cover_percent= $cover_divisor_trunc;

my $assert_divisor= $assert_count/$rtl_total;
my $assert_divisor_trunc= sprintf("%.2f",$assert_divisor*100); 
my $assert_percent= $assert_divisor_trunc;  
=comment
my $total_sum=0;
my $blocks_sum=0;

%block_sum=();

foreach my $key ( keys %top )  
{
    foreach my $blocks( keys %{$top{$key}} )  
    {
      foreach my $final ( keys %{$top{$key}{$blocks}} ) 
      {
        foreach ( @{ $top{$key}{$blocks}{$final} }  )  
        {
            $blocks_sum+=$_;
            $total_sum+=$_;
        }
        $block_sum{$blocks}= $blocks_sum;
        print $block_sum{$blocks};
        $blocks_sum=0;
      }
#      print KEYS "\t\t\t\t$blocks\n";
#      print KEYS "\t\t\t\t\t$sum\n";
      
    }
}
=cut 

#######################################################
#XML_output with DUMPER
=comment
my $dump=new XML::Dumper;
my $xml = '';
$xml=$dump-> pl2xml(\%top);
print $xml;
=cut

#######################################################
#XML output with SIMPLE
=comment 
my $xs= new XML::Simple;
print FILE_LOG "<?xml version = '1.0' encoding=\"ISO-8859-1\"?>\n<?xml-stylesheet type=\"text/xsl\" href=\"sva_density.xsl\"?>\n";
my $xml_output= $xs->XMLout(\%top, NoAttr=>1, RootName=> $partition);
#my $xml_output= $xs->XMLout(\%top, RootName=> $partition);
#my $xml_output= $xs->XMLout(\%top);#, RootName=> $partition);
print FILE_LOG $xml_output;
=cut

#######################################################
#XML output manually created
my $block_cov_sum=0;
my $block_rtl_sum=0;
my $block_percentage=0;
my $block_trunc=0;
my $block_percent=0;
my %block_coverage_sum=();
my %block_rtl_sum=();
print KEYS "<?xml version = '1.0' encoding=\"ISO-8859-1\"?>\n<?xml-stylesheet type=\"text/xsl\" href=\"sva_density.xsl\"?>\n";
print KEYS "<top>\n\t<topname>$partition</topname>\n";
print KEYS "<version>\n\t<generated>$revised_date</generated>\n</version>\n";
print KEYS "<top_stats>\n\t<total_assert_lines>$assert_count</total_assert_lines>\n\t<total_cover_lines>$cover_count</total_cover_lines>\n\t<total_coverage_lines>$coverage_total</total_coverage_lines>\n\t<total_rtl_lines>$rtl_total</total_rtl_lines>\n\t<total_assert_percent>$assert_percent</total_assert_percent>\n\t<total_cover_percent>$cover_percent</total_cover_percent>\n\t<total_percent>$percent</total_percent>\n</top_stats>\n";
foreach my $key ( keys %top )  {
    print KEYS "\t<partition>\n\t\t<pname>$key</pname>\n";

    foreach my $blocks( keys %{$top{$key}} )  {
      print KEYS "\t\t<block>\n\t\t\t<bname>$blocks</bname>\n"; 
      
      foreach my $final ( keys %{$top{$key}{$blocks}} ) {
          $block_cov_sum+=$top{$key}{$blocks}{$final}[1];
          $block_rtl_sum+=$top{$key}{$blocks}{$final}[2];
       print KEYS "\t\t\t<filename>\n\t\t\t\t<fname>$final</fname>\n";
       # foreach ( @{ $top{$key}{$blocks}{$final} }  )  {
       
            print KEYS "\t\t\t\t<percent>$top{$key}{$blocks}{$final}[0]</percent>\n";
            print KEYS "\t\t\t\t<coverage>$top{$key}{$blocks}{$final}[1]</coverage>\n";
            print KEYS "\t\t\t\t<rtl>$top{$key}{$blocks}{$final}[2]</rtl>\n";
            print KEYS "\t\t\t\t<assert>$top{$key}{$blocks}{$final}[3]</assert>\n";
            print KEYS "\t\t\t\t<assert_percent>$top{$key}{$blocks}{$final}[4]</assert_percent>\n";

            print KEYS "\t\t\t\t<cover>$top{$key}{$blocks}{$final}[5]</cover>\n";
            print KEYS "\t\t\t\t<cover_percent>$top{$key}{$blocks}{$final}[6]</cover_percent>\n";


       # }
       print KEYS "\t\t\t</filename>\n";
      }
#      print KEYS "\t\t\t\t$blocks\n";
#      print KEYS "\t\t\t\t\t$sum\n";
      $block_coverage_sum{"$blocks"}="$block_cov_sum";
      $block_rtl_sum{"$blocks"}="$block_rtl_sum";
      if($block_cov_sum!=0)
      {
          $block_percentage= $block_cov_sum/$block_rtl_sum;
          $block_trunc= sprintf("%.2f",$block_percentage*100); 
          $block_percent= $block_trunc;
      }
      else
      {
          $block_percentage=0;
      }
      
      print KEYS "\t\t<block_cov_sum>$block_coverage_sum{$blocks}</block_cov_sum>\n";
      print KEYS "\t\t<block_rtl_sum>$block_rtl_sum{$blocks}</block_rtl_sum>\n";
      print KEYS "\t\t<block_percent>$block_percent</block_percent>\n";
      $block_cov_sum=0;
      $block_rtl_sum=0;
      $block_percentage=0;
      print KEYS "\t\t</block>\n";
    }
    print KEYS "\t</partition>\n";
  }
print KEYS "</top>";

#######################################################

foreach my $key ( keys %top )  {
    print KEYS_RTL "$key\n";
    foreach my $blocks( keys %{$top{$key}} )  {
      print KEYS_RTL "\t$blocks\n";
      foreach my $final ( keys %{$top{$key}{$blocks}} ) {
       print KEYS_RTL "\t\t$final\n";
        foreach ( @{ $top{$key}{$blocks}{$final} }  )  {
          print KEYS_RTL "\t\t\t$_\n";
          
        }
      }
#      print KEYS "\t\t\t\t$blocks\n";
#      print KEYS "\t\t\t\t\t$sum\n";
      
    }
  }
=comment
else
{
    print FILE_LOG "DONT PARSE-";
    print FILE_LOG $path;
    print FILE_LOG "\n";
}
=cut


close CONN;
close IN;
close PARSE;
close NP;

#`rm -rf $log_dir`;

##############################
#Print to console
##############################
=comment
print "********************************\n";
print "Number of COVERS in $partition RTL    = $cover_count\n";
print "********************************\n";
print "\n";

print "********************************\n";
print "Number of ASSERTS in $partition RTL   = $assert_count\n";
print "********************************\n";
print "\n";

print "********************************\n";
print "Total lines of coverage in $partition = $coverage_total\n";
print "********************************\n";
print "\n";

print "********************************\n";
print "Total lines of RTL in $partition      = $rtl_total\n";
print "********************************\n";
print "\n";


print "********************************\n";
print "Coverage Lines\n---------------  for $partition       = $divisor\n  RTL lines\n";
print "********************************\n";
print "\npercentage=$percent\%";
print "\n";
=cut

##############################
#Print to output file that will be linked to sharepoint
##############################

print FILE_LOG "\n\n\nNumber of COVERS in $partition RTL    = $cover_count\n";

print FILE_LOG "Number of ASSERTS in $partition RTL   = $assert_count\n";

print FILE_LOG "Total lines of coverage in $partition = $coverage_total\n";

print FILE_LOG "Total lines of RTL in $partition      = $rtl_total\n\n";

print FILE_LOG "-------------------------------------------------------------\n";
print FILE_LOG "Percentage of lines of coverage per lines of RTL = $percent\% \n" ;


close FILE_LOG;
close KEYS;
close KEYS_RTL;
}



sub prepare_usage { # {{{
    push(@usage,<<"EOD");
    USAGE:  $scname   -g
            $scspcs  [flags] [-help]
    Flag descriptions:
    --help            gets this usage message.
    -g                provides coverage information for glb
    -c                provides coverage information for chn
    -m                provides coverage information for msc
 

    NOTES: This script will count the number of lines of coverage
           per lines of RTL within a partition. 
           Current partitions supported are: glb, chn, msc
    
EOD
} # }}}





# Modeline for ViM {{{
# vim:set ft=perl ts=4 sts=4 ts=4 sw=4 expandtab:
# vim600:fdm=marker fdl=0 fdc=3:
# }}}


