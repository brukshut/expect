#!/opt/mlb/bin/expect 

## print_html.tcl
## generates netscaler stats in html; utilizes serverlist datastructure

## source common procedures
source /opt/expect/common.tcl
source /opt/expect/nscommon.tcl
source /opt/expect/show_lbvservers.tcl

set basedir "/opt/netscaler/htdocs/nsinfo"

## Procaway Beach
proc print_lbvserver_header {nshost} {
  global basedir 
  global NSFD
  set timestamp [clock format [clock seconds] -format {[%d/%h/%Y:%H:%M:%S]}]
  set lbvs_header "  <tr>
     <td class=\"topheader\" colspan=\"5\">
       <div class=\"largeheader\">$timestamp $nshost: PRIMARY</div>
     </td>
   </tr>"
  puts $NSFD $lbvs_header;
}

proc print_lbvserver_rows {lbvserver} {
  global NSFD
  global service_list

  set timestamp [clock format [clock seconds] -format {[%d/%h/%Y:%H:%M:%S]}]
  set lbvsinfo "  <tr>
  <td class=\"header_row\" colspan=\"5\">
    <div class=\"header\"><a name=\"$lbvserver\">$timestamp $lbvserver</a></div>
  </td>
</tr>"
  puts $NSFD $lbvsinfo
  set services [keylkeys service_list]
  set nextcolor grey
  foreach service $services {
    set ip      [keylget service_list $service.ip]
    set port    [keylget service_list $service.port]
    set state   [keylget service_list $service.state]
    set hits    [keylget service_list $service.hits]
    set req     [keylget service_list $service.req]
    set rsp     [keylget service_list $service.rsp]
    set thruput [keylget service_list $service.thruput]
    set surgeq  [keylget service_list $service.surgeq]
    set cltcon  [keylget service_list $service.cltcon]
    set svrcon  [keylget service_list $service.svrcon]
    set svrttfb [keylget service_list $service.svrttfb]
    set reusep  [keylget service_list $service.reusep]
    set maxcon  [keylget service_list $service.maxcon]
    set acttran [keylget service_list $service.acttran]
    set svrload [keylget service_list $service.svrload]

    if {![string compare $nextcolor "grey"]} {
      set rowcolor $nextcolor
      set nextcolor "white"
    } elseif {![string compare $nextcolor "white"]} {
      set rowcolor $nextcolor
      set nextcolor "grey"
    }
    regsub {_[0-9]{2,}} $service {} host
    set lbvsrow "<tr><td style=\"width: 136px\" class=\"row ${rowcolor}\"><div class=\"row\">
  <a class=\"textlink\" href=\"index.php?page=webhosts#$host\">$service</a></div></td>
  <td style=\"width: 100px\" class=\"row right ${rowcolor}\"><div class=\"row\">conn: $svrcon</div></td>
  <td style=\"width: 100px\" class=\"row right ${rowcolor}\"><div class=\"row\">ttfb: $svrttfb</div></td>
  <td style=\"width: 100px\" class=\"row right ${rowcolor}\"><div class=\"row\">surgeq: $surgeq</div></td>
  <td style=\"width: 100px\" class=\"row right ${rowcolor}\"><div class=\"row\">state:
"
    puts $NSFD $lbvsrow

    switch $state {
      "DOWN" { set colorstate "red" }
      "UP"   { set colorstate "green" }
      "OFS"  { set colorstate "black" }
    }
    puts $NSFD "<span style=\"color: $colorstate\">$state</style></div></td></tr>"
  }
  #set endhtml "</div></table>
  #</body>
  #</html>"
  #puts $NSFD $endhtml
}
