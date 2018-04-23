#!/usr/bin/expect

## $Id: show_lbvservers.tcl 211 2011-01-06 17:58:32Z cgough $
## "show lbvservers" ns command written in tcl/expect

## love of the common people
source /opt/expect/common.tcl
source /opt/expect/nscommon.tcl

## begin procedure

## inherits invoking spawn_id and issues "show lbvservers" 
## parses ns cli output and returns list of lbvservers
proc show_lbvservers {nshost} {
  upvar spawn_id spawn_id
  match_max 100000
  set timeout -1
  #stty -echo
  send --  "show lbvservers | grep ^\[0-9\] -E\r"
  expect -ex "> " {
    set accum "$expect_out(buffer)"
    set clean [stripchars $accum]
    ## Strip out any characters from NS command
    set clean [wschomp [regsub -all {[[:space:]]+} $clean { }]]
    set clean [wschomp [regsub -all { } $clean {,}]]
    set clean [wschomp [regsub -all "show,lbvservers,grep,09,E" $clean {}]]
    set clean [wschomp [regsub -all ",HTTP,Type,ADDRESS," $clean {}]]
    set clean [wschomp [regsub -all {(^;|;$)} $clean {}]]
    set clean [regsub -all {;} $clean { }]

    ## useful for debugging
    #puts "ACCUM --> $accum"
    #puts "CLEAN --> $clean"

    set lines [split $clean { }]
    set lbvslist {}
    foreach line $lines {
      set fields [split $line ","]
      lassign $fields number lbvs ipaddr port
      lappend lbvslist $lbvs
    } 
  }
  set lbvslist [lsort -ascii $lbvslist]
  return $lbvslist
}

## end procedure