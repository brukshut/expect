#!/usr/bin/expect

## common.tcl 
## This library provides a set of expect procedures that
## are useful for automating datacenter tasks.

## This returns the hostlists available to an expect script.
proc return_hostlists {} {
  set basename [exec pwd]
  return [exec ls -m ${basename}/hostlists]
}

## parse_list parses a hostlist into a tcl list variable that we
## easily step through.  It skips commented lines.
proc parse_list {list} {
  if {[catch {open $list r} input]} {
    error $input
  } else {
    gets $input line
    while {![eof $input]} {
      ## Ignore commented lines in hostlist.
      if {[regexp {^[^\#]} $line]} {
        lappend hostlist $line
      }
      gets $input line
    }
    close $input
    return $hostlist
  }
}

## error_report is a buffer that collects the output of various procedures.
## When a script is done executing, print this report into a unique file.
## Then, link ${username}_failed_hosts to this report file.
proc print_error_report {username script error_report} {
  set ts [exec date +%m%d%y.%H%M.%S]
  set fileout ".${username}.${script}.report.txt.${ts}"
  if {[file exists "hostlists/${username}_failed_hosts"] == 1} {
    exec rm hostlists/${username}_failed_hosts
  }
  if {[llength $error_report] > 1} {
    if {[catch {open "hostlists/$fileout" w} input]} {
      error $input
    } else {
      foreach report $error_report {
        puts $input $report            
      }
      close $input
    }
    set basename [exec pwd]
    exec ln -s ${basename}/hostlists/$fileout ${basename}/hostlists/${username}_failed_hosts
    puts "REPORT: hostlists/${username}_failed_hosts"
  }
}

## Simple procedure to prompt user for a password, entered twice.
proc passwd_prompt {} {
  set timeout -1
  stty -echo
  set match n
  while {[string compare $match "n"] == 0} {
    send_user "Password: "
    expect_user -re "(.*)\n"
    set passwd $expect_out(1,string)
    send_user "\n"
    send_user "Re-enter Password: "
    expect_user -re "(.*)\n"
    set passwd_verify $expect_out(1,string)
    send_user "\n"
    if {[string compare $passwd $passwd_verify] == 0} {
      puts "Passwords match."
      set match y
    } else {
      puts "Passwords don't match."
      set match n
    }
  }
  stty echo 
  return $passwd
}

## Simple procedure to prompt a user for input.
proc input_prompt {prompt} {
  set timeout -1
  send_user "$prompt: "
  expect_user -re "(.*)\n"
  set input $expect_out(1,string)
  return $input
}
