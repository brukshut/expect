#!/usr/bin/expect

## $Id: stat_lbvserver.tcl 244 2011-03-16 21:10:52Z cgough $
## "stat lbvserver $lbvs" ns command written in tcl/expect

## love of the common people
source /opt/expect/common.tcl
source /opt/expect/nscommon.tcl

## stat_lbvserver uses tclx keylist data structure
package require Tclx

## procedures
proc stat_lbvserver {netscaler lbvserver} {
  upvar spawn_id spawn_id
  match_max 10000
  set timeout 10
  set timestamp [clock format [clock seconds] -format {[%d/%h/%Y:%H:%M:%S]}]
  send -- "stat lbvserver $lbvserver | grep \'^(esc|scc|mdweb|sclweb|qaweb|web|cache|t|ct)\[0-9\]\[0  -9\]\' -E\r"
  expect -re "\n> " {
    set accum "$expect_out(buffer)"
    ## $accum is the raw response from our stat lbvserver command piped through grep
    ## useful for debugging
    set clean $accum
    set clean [stripchars $accum]
    set clean [wschomp [regsub -all {[[:space:]]+} $clean { }]]
    set clean [wschomp [regsub -all { } $clean {,}]]
    set clean [regsub "stat,lbvserver,$lbvserver,grep,escsccmdwebsclwebqawebwebcachetct,0909,E" $clean {}]
    set clean [regsub -all {;} $clean { }]
    set lines [split $clean " "]
    set count 1
    foreach line $lines {
      if {[regexp {^(esc|scc|sclweb|qaweb|beta|web|cache|t|ct)} $line]} {
        regexp {(^[^,]+),(.*$)} $line match service stats
        if {![info exists services($service)]} {
          set services($service) "$stats"
        } else {
          set services($service) "$services($service),$stats"
        }
      }
    } 
    set arraysize [array size services]
    if {$arraysize == 0} { 
      error "$lbvserver has no hosts" 
    }
    foreach servicename [lsort [array names services]] {
      ## Use this for debugging:
      #puts "$servicename --> $services($servicename)"
      ##web29_78 --> 172.20.28.29,78,HTTP,UP,4170167,6514328,6457795,0,0,0,21,9,500,0,0,0
      set fields [split $services($servicename) ","]
      lassign $fields ip port type state hits req rsp thruput cltcon surgeq svrcon reusep maxcon acttran svrttfb svrload
      regsub {OUT} $state {OFS} state
      keylset service_list $servicename.ns      $netscaler
      keylset service_list $servicename.lbvs    $lbvserver
      keylset service_list $servicename.ip      $ip
      keylset service_list $servicename.port    $port
      keylset service_list $servicename.state   $state
      keylset service_list $servicename.hits    $hits
      keylset service_list $servicename.req     $req
      keylset service_list $servicename.rsp     $rsp
      keylset service_list $servicename.thruput $thruput
      keylset service_list $servicename.cltcon  $cltcon
      keylset service_list $servicename.surgeq  $surgeq
      keylset service_list $servicename.svrcon  $svrcon
      keylset service_list $servicename.reusep  $reusep
      keylset service_list $servicename.maxcon  $maxcon
      keylset service_list $servicename.acttran $acttran
      keylset service_list $servicename.svrttfb $svrttfb
      keylset service_list $servicename.svrload $svrload

    }

  }
  return [lsort -ascii $service_list]
}    

## end procedures
