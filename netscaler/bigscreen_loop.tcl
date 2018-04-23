#!/usr/bin/expect 

## bigscreen_loop.tcl 
## logs into netscalers and fetches lbvserver status
package require Tclx

## source common procedures
source /opt/expect/common.tcl
source /opt/expect/nscommon.tcl
source /opt/expect/show_lbvservers.tcl
source /opt/expect/stat_lbvserver.tcl

## PROCEDURES
proc usage {scriptname} {
  puts -nonewline "Usage: ${scriptname}.tcl "
  puts {[netscaler] [interval] {[searchterms]}}
  puts {Options:}
  puts {  [netscaler] is the hostname or ip of a netscaler.}
  puts {  [interval] is the number of seconds between polls.}
  puts {  {[searchterms]} optional comma-separated list of search terms.}
  exit
}

proc excludelist {lbvservers} {
  set excludelist {}
  foreach lbvserver $lbvservers { 
    if {![regexp {qa|beta|test} $lbvserver]} {
      lappend excludelist $lbvserver
    }
  }
  return $excludelist
}

proc includelist {lbvservers includeterms} {
  set includelist {}
  foreach lbvserver $lbvservers { 
    foreach includeterm [split $includeterms {,}] {
      if {[regexp $includeterm $lbvserver found] } {
        lappend includelist $lbvserver
      }    
    }
  }
  return $includelist
}

## END PROCEDURES

## CONTROLLING LOGIC

## enable this to watch ouput
#log_user 1
log_user 0
set scriptname [file rootname [file tail $argv0]]

if {$argc < 2} { 
  usage $scriptname
} else {
  set netscaler [lindex $argv 0]  
  if {[regexp {^[0-9]?$} [lindex $argv 1]]} {
    set interval [lindex $argv 1]
  } else {
    usage $scriptname
  }
  if {![info exists [lindex $argv 2]]} {
    set searchterms [lindex $argv 2]
  }
}

## we can safely prompt for these if necessary
set nsuser "xxxx"
set nspasswd "xxxx"
set timeout 8
set loopcount 0

if {[catch {set spawn_id [ns_primary_connect $nsuser $nspasswd $netscaler]} out]} {
  puts $out
  exit
} else {
  while {$loopcount <= 1000} {
    puts -nonewline "Retrieving list of lbvservers on $netscaler... "
    set lbvservers [show_lbvservers $netscaler]
    set lbvservers [excludelist $lbvservers]

    if {[llength $searchterms] > 0} { 
      set lbvservers [includelist $lbvservers $searchterms] 
    }
    puts "DONE."
    puts "LBVSERVERS: $lbvservers\n"
    foreach lbvserver $lbvservers {
      set timestamp [clock format [clock seconds] -format {[%d/%h/%Y:%H:%M:%S]}]
      if {![catch {set service_list [stat_lbvserver $netscaler $lbvserver]} out]} {

        sleep $interval
        set services [keylkeys service_list]
        set service_count [llength $services]
        puts -nonewline [format "%-57s %-17s\n" "$timestamp \[$lbvserver\]" "\[services: $service_count\]"]
        foreach service $services {
          set state   [keylget service_list $service.state]
          set svrcon  [keylget service_list $service.svrcon]
          set surgeq  [keylget service_list $service.surgeq]
          set svrttfb [keylget service_list $service.svrttfb]
          set svrload [keylget service_list $service.svrload]
          set cltcon  [keylget service_list $service.cltcon]
          set colorstate "\033\[01;32m${state}\033\[0m"
          if {![string compare $state "DOWN"]} { set colorstate "\033\[01;31m$state\033\[0m" }
          puts [format "%-14s %-14s %-14s %-14s %-28s" "$service" "SVRCON: $svrcon" "CLTCON: $cltcon" "SURGEQ: $surgeq" "STATE: $colorstate"]
        }
        puts -nonewline "\n"
      }
    }
  incr loopcount
  }	
}
## end main()
