#!/usr/bin/expect

## show_services.tcl 
## "show services" ns command written in tcl/expect

## love of the common people
source /opt/expect/common.tcl
source /opt/expect/nscommon.tcl

## show_services uses tclx keylist data structure
package require Tclx

proc show_services {lbvserver} {
  #upvar spawn_id spawn_id
  match_max 100000
  set timeout 10
  send -- "show lbvserver $lbvserver | grep \'^\[0-9\]+\[)\] (qa|web|ct|cache|t)\' -E\r"
  expect "> " {
    ## accum is the accumulated text of both the send command and the response.
    ## The first thing we do is strip the following []()-^+:|'\r\n\t
    set accum "$expect_out(buffer)"
    set clean [stripchars $accum]
    set clean [regsub -all {[[:space:]]+} $clean { }]
    set clean [wschomp [regsub -all { } $clean {,}]]
    set clean [wschomp [regsub -all "show,lbvserver,$lbvserver,grep,09,qawebctcachet,E" $clean {}]]
    ## Now the remaining stuff in $clean should be our data.
    set clean [wschomp [regsub -all {,HTTP,State} $clean {}]]
    set clean [wschomp [regsub -all {,Weight,[0-9]+} $clean {}]]
    set clean [wschomp [regsub -all {OUT,OF,SERVICE} $clean {OFS}]]
    set clean [wschomp [regsub -all "(UP|DOWN|OFS)" $clean "\\1"]]
    set clean [regsub -all {(^;|;$)} $clean {}]

    ## useful for debugging
    #puts "ACCUM --> $accum"
    #puts "CLEAN --> $clean"

    ## $clean by now consists of a long colon-delineated string:
    ##
    ##   1,web21_80,172.20.28.21,80,UP;2,web22_80,172.20.28.22,80,UP
    ##
    ## Now, turn our newline character back to a single whitespace.
    ## Tcl will then interpret each services as an individual list item.
    set lines [regsub -all {;} $clean { }]
    set servicelist {}
    foreach line $lines {
      set fields [split $line ","]
      lassign $fields number service ipaddr port state
      lappend servicelist "$service:$state"
    }
  }
  return [lsort -ascii $servicelist]
}

### END PROCEDURES
