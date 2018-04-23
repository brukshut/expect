#!/opt/mlb/bin/expect 

## collect_nsinfo.tcl 
## expect script to scrape netscalers for lbvservers info
## takes aggregated data and spits out html and hosts files

## required for keylists
package require Tclx

## Determine name of script for accounting purposes.
set scriptname [file rootname [file tail $argv0]]

## Usage.
if {$argc != 1} {
  puts "Usage: ${scriptname}.tcl \[interval\]"
  puts {Options:}
  puts {  [interval] is the number of seconds between polls.}
  exit
} else {
  set interval [lindex $argv 0]
}

## source common functions
source /opt/expect/common.tcl
source /opt/expect/nscommon.tcl
source /opt/expect/show_lbvservers.tcl
source /opt/expect/stat_lbvserver.tcl
source /opt/expect/print_html.tcl
source /opt/expect/print_webhosts.tcl

## CONTROLLING LOGIC

## This should enable/disable echo'ing of chars
#log_user 1
log_user 0

set nsuser "xxxx"
set nspasswd "xxxx"
set timeout 8

set nshostlist "ns01 ns02 ns03 ns04"
set nsinfo {}
set htdocs "/opt/netscaler/htdocs/nsinfo"
array set webhosts {}

foreach netscaler $nshostlist {
  if {[catch {set spawn_id [ns_primary_connect $nsuser $nspasswd $netscaler]} out]} {
    puts $out
    continue
  } else {
    set lbvservers [show_lbvservers $netscaler]
    switch $netscaler {
      "ns01" { set filename "ns0102" }
      "ns02" { set filename "ns0102" }
      "ns03" { set filename "ns0304" }
      "ns04" { set filename "ns0304" }
    }
    set oldfile "$filename.html"
    set newfile ".$filename.html"
    set NSFD [open "$htdocs/$newfile" w] 
    print_lbvserver_header $netscaler
    foreach lbvserver $lbvservers {
      sleep $interval
      if {![catch {set service_list [stat_lbvserver $netscaler $lbvserver]} out]} {
        print_lbvserver_rows $lbvserver
        set services [keylkeys service_list]
        foreach service $services {
          regsub {_[0-9]{2,}} $service {} host
          set ns     [keylget service_list $service.ns]
          set lbvs   [keylget service_list $service.lbvs]
          set port   [keylget service_list $service.port]
          set state  [keylget service_list $service.state]
          set state  [keylget service_list $service.state]
          set cltcon [keylget service_list $service.cltcon]
          ## push to array
          lappend webhosts($host) $port:$ns:$lbvs:$cltcon:$state
        }
        set nsinfo [concat $nsinfo $service_list]
      }
    }
    close $NSFD
    file rename -force "$htdocs/$newfile" "$htdocs/$oldfile"
  }
}

## print_webhosts consumes nsinfo
print_webhosts

## end main()

