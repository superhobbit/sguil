# $Id: SguildUtils.tcl,v 1.3 2004/10/18 17:05:56 shalligan Exp $ #

proc Daemonize {} {
    global PID_FILE env LOGGER
    set childPID [fork]
    # Parent exits.
    if { $childPID == 0 } { exit }
    id process group set
    if {[fork]} {exit 0}
    set PID [id process]
    if { ![info exists PID_FILE] } { set PID_FILE "/var/run/sguild.pid" }
    set PID_DIR [file dirname $PID_FILE]
    if { ![file exists $PID_DIR] || ![file isdirectory $PID_DIR] || ![file writable $PID_DIR] } {
	LogMessage "ERROR: Directory $PID_DIR does not exists or is not writable. Process ID will not be written to file."
    } else {
	set pidFileID [open $PID_FILE w]
	puts $pidFileID $PID
	close $pidFileID
    }
}

proc HupTrapped {} {
  global AUTOCAT_FILE GLOBAL_QRY_FILE GLOBAL_QRY_LIST clientList REPORT_QRY_FILE REPORT_QRY_LIST
  global acRules acCat ACCESS_FILE
  LogMessage "HUP signal caught."
  # Reload auto cat rules
  InfoMessage "Reloading AutoCat rules: $AUTOCAT_FILE"
  # Clear the current rules
  if [info exists acRules] { unset acRules }
  if [info exists acCat] { unset acCat }
  if { [ file exists $AUTOCAT_FILE] } {
    LoadAutoCatFile $AUTOCAT_FILE
  }
  # reload global queries.
  InfoMessage "Reloaded Global Queries: $GLOBAL_QRY_FILE"
  # Clear the current list
  set GLOBAL_QRY_LIST ""
  if { [file exists $GLOBAL_QRY_FILE] } {
    LoadGlobalQueries $GLOBAL_QRY_FILE
  } else {
    set GLOBAL_QRY_LIST none
  }
  set REPORT_QRY_LIST ""
  if { [file exists $REPORT_QRY_FILE] } {
     LoadReportQueries $REPORT_QRY_FILE
  } else {
    set REPORT_QRY_LIST none
  }
  foreach clientSocket $clientList {
    SendSocket $clientSocket "GlobalQryList $GLOBAL_QRY_LIST"
    SendSocket $clientSocket "ReportQryList $REPORT_QRY_LIST"
  }
  LoadAccessFile $ACCESS_FILE
}

proc GetRandAlphaNumInt {} {
  set x [expr [random 74] + 48]
  while {!($x >= 48 && $x <= 57) && !($x >= 65 && $x <= 90)\
      && !($x >= 97 && $x <= 122)} {
     set x [expr [random 74] + 48]
  }
  return $x
}

#
# GetHostbyAddr: uses extended tcl (wishx) to get an ips hostname
#                May move to a server func in the future
#
proc GetHostbyAddr { ip } {
  if [catch {host_info official_name $ip} hostname] {
    set hostname "Unknown"
  }
  return $hostname
}

proc GetCurrentTimeStamp {} {
  set timestamp [clock format [clock seconds] -gmt true -f "%Y-%m-%d %T"]
  return $timestamp
}

#
# ldelete: Delete item from a list
#
proc ldelete { list value } {
  set ix [lsearch -exact $list $value]
  if {$ix >= 0} {
    return [lreplace $list $ix $ix]
  } else {
    return $list
  }
}

# Reads file and adds queries to GLOBAL_QRY_LIST
proc LoadGlobalQueries { fileName } {
  global GLOBAL_QRY_LIST
  for_file line $fileName {
    if { ![regexp ^# $line] && ![regexp ^$ $line] } {
      lappend GLOBAL_QRY_LIST $line
    }
  }
}
# Reads file and adds report queries to REPORT_QRY_LIST
proc LoadReportQueries { fileName } {
    global REPORT_QRY_LIST
    set REPORT_QRY_LIST ""
    for_file line $fileName {
        if { ![regexp ^# $line] && ![regexp ^$ $line] } {
            set REPORT_QRY_LIST "${REPORT_QRY_LIST}${line}"
        }
    }
    #regsub -all {\n} $REPORT_QRY_LIST {} $REPORT_QRY_LIST
}

#  Puts an error to std_out or to syslog if in daemon
#  mode and then calls CleanExit {}
proc ErrorMessage { msg } {
    global DAEMON LOGGER
    if { $DAEMON && [string length $LOGGER] > 0 } {
	Syslog $msg err
    } else {
	puts $msg
    }
    CleanExit
}

#  Puts a message to std_out or to syslog if in daemon
#  mode only if debug == 2.  Use this for noisy less important
#  messages
proc InfoMessage { msg } {
    global DEBUG DAEMON LOGGER
    if { $DEBUG > 1 } {
	if { $DAEMON && [string length $LOGGER] > 0 } {
	    Syslog $msg info
	} else {
	    puts $msg
	}
    }
}

#  Puts a message to std_out or to syslog if in daemon
#  mode only if debug >  0.  Use this for important messages
#  that we don't need to die on.
proc LogMessage { msg } {
    global DEBUG DAEMON LOGGER
    if { $DEBUG > 0 } {
	if { $DAEMON && [string length $LOGGER] > 0 } {
	    Syslog $msg notice
	} else {
	    puts $msg
	}
    }
}

#  Logs a message to syslog to the facility defined by the
#  SyslogFacility conf option
proc Syslog { msg level } {
    global SYSLOGFACILITY
    catch { exec logger -t "SGUILD" -p "$SYSLOGFACILITY.$level" $msg } logError
}