#!/usr/bin/expect

## nscommon.tcl 
## This is a set of expect procedures that are useful
## when writing netscaler scripts.

## begin procedures

## connect to primary netscaler only and return spawn_id 
proc ns_primary_connect {nsuser nspasswd nshost} { 
  spawn ssh -l $nsuser $nshost
  expect {
    timeout { 
      error "$nshost: timed out"
    }  -re "(.*)Host key verification failed" {
      error "$nshost: It is possible that the RSA host key has changed."
    } -re "\(yes\/no\)" {
       send -- "yes\r"
       exp_continue
    } -re "Password:" {
      send -- "$nspasswd\r"
      expect  -re "(.*)You are connected to a secondary node(.*)Done\r\n" {
        send -- "exit\r";
        error "Cowardly! $nshost is SECONDARY"
      } -re "(.*)Done\r\n\> " {
        ## chariots of fire theme music
        puts "Using PRIMARY NS $nshost"
        return $spawn_id
      }
    }
  }
}

## wschomp removes leading and trailing whitespace from a string
proc wschomp {mystring} {
  set clean $mystring
  set clean [regsub {^[[:space:]]+} $clean {}]
  set clean [regsub {[[:space:]]+$} $clean {}]
  return $clean
}

## Designed to clean $expect_out of any troublesome characters.
## I preserve newlines here which I use later to split into lines.
proc stripchars {filth} {
  set timeout -1
  set clean $filth
  ## Important.  Here we preserve newlines.
  ## Choose your character wisely.  Semi-colon.
  set clean [regsub -all {\n} $clean {;}]
  set clean [regsub -all {\r} $clean {}]
  set clean [regsub -all {\t} $clean { }]
  set clean [regsub -all {[()]} $clean { }]   
  set clean [regsub -all {[\[\]]} $clean {}]   
  set clean [regsub -all {[\-]} $clean {}]
  set clean [regsub -all {\^} $clean {}]
  set clean [regsub -all {\+} $clean {}]
  set clean [regsub -all {\'} $clean {}]
  set clean [regsub -all {\>} $clean {}]
  set clean [regsub -all {\|} $clean {}]
  set clean [regsub -all {:} $clean { }]
  return [wschomp $clean]
}

## cheater show_services.  
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

## end procedures
