#!/usr/bin/expect

## $Id: print_webhosts.tcl 210 2011-01-04 23:20:32Z cgough $

proc print_webhosts {} {
  ## grab our datastructure
  upvar webhosts webhosts
  set basedir "/opt/netscaler/htdocs/nsinfo"
  set newfile "webhosts.html"
  set oldfile ".webhosts.html"
  set WEBHOSTS [open "$basedir/$newfile" w] 
  set endhtml "    </table>
</div>
</body>
</html>"

  set timestamp [clock format [clock seconds] -format {[%d/%h/%Y:%H:%M:%S]}]
  set webhostsbanner "<tr>
  <td class=\"topheader\" colspan=\"5\">
    <div class=\"largeheader\">Webhosts: Netscaler lbvservers by Host</div>
  </td>
</tr>
<tr>
  <td class=\"largeheader_row\" colspan=\"5\" style=\"width: 539px\">
    <div class=\"largeheader\">Generated $timestamp</div>
  </td>
</tr>"
  puts $WEBHOSTS $webhostsbanner
  foreach webhost [lsort [array names webhosts]] {
    ## Spit out snazzy header
    set trendsurl "http://172.20.43.65/msdadm/html/${webhost}-dc2.trends.html"
    set webhostheader "<tr>
  <td class=\"header_row\" style=\"width: 439px\" colspan=\"4\">
    <div class=\"header\">
      <a name=\"$webhost\">$webhost</a>
    </div>
  </td>
  <td class=\"white right\" style=\"width: 100px\" colspan=\"1\">
    <div class=\"header\">
      <a class=\"pagelink\" href=\"$trendsurl\">TRENDS</a>
    </div>
  </td>
</tr>
"
    puts $WEBHOSTS $webhostheader
    set nextcolor "grey"
    foreach lbvsinfo [lsort [split $webhosts($webhost) { }]] {
      set fields [split $lbvsinfo ":"]
      lassign $fields port ns lbvs cltcon state 
      if {![string compare $nextcolor "grey"]} {
        set rowcolor $nextcolor
        set nextcolor "white"
      } elseif {![string compare $nextcolor "white"]} {
        set rowcolor $nextcolor
        set nextcolor "grey"
      }
      switch $ns {
        "ns01" { set filename "ns0102" }
        "ns02" { set filename "ns0102" }
        "ns03" { set filename "ns0304" }
        "ns04" { set filename "ns0304" }
      }
      switch $state {
        "DOWN" { set colorstate "red" }
        "UP"   { set colorstate "green" }
        "OFS"  { set colorstate "black" }
      }
      set webhostrow "  <tr>
  <td style=\"width: 50px\" class=\"row $rowcolor\">
    <div class=\"row\">$ns</div>
  </td>
  <td style=\"width: 50px\" class=\"row $rowcolor right\">
    <div class=\"row\">$port</div>
  </td>
  <td style=\"width: 256px\" class=\"row $rowcolor right\">
    <div class=\"row\">
      <a class=\"textlink\" href=\"index.php?page=$filename#$lbvs\">$lbvs</a>
    </div>
  </td>
  <td style=\"width: 80px\" class=\"row $rowcolor right\">
    <div class=\"row\">conn: $cltcon</div>
  </td>
  <td style=\"width: 100px\" class=\"row $rowcolor right\">
    <div class=\"row\">state:
      <span style=\"color: $colorstate\"> $state</style>
    </div>
  </td>
</tr>"
      puts $WEBHOSTS $webhostrow
    }
  }
  puts $WEBHOSTS $endhtml
  close $WEBHOSTS
}
