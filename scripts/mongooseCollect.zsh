#!/bin/zsh --no-rcs
####################################################################################################
#
# ABOUT
#
#   Mongoose Collect
#
#   Gathers the client-side logs a full Mongoose audit reads into one flat .zip archive:
#   system.log, the MDM agent log and the organization's script logs (a reverse-domain script
#   log, Parameter 4, and/or every plain *.log at any depth under a per-script log directory,
#   Parameter 8), plus install.log, App Auto-Patch and EPM audit logs when present, Jamf Pro
#   Self Service+ entries exported from Unified Logging when Self Service+ is installed, and a
#   collection manifest (collection time with offset, macOS build, boot time, serial number,
#   and per-member size, modification time, SHA-256 and source path).
#
#   Transferring the .zip is out of scope; the archive stays in the output directory.
#   Mongoose reads the archive off the Mac; nothing here runs an agent or LLM.
#
#   Run as root, for example from a Jamf Pro policy, or locally:
#       sudo zsh mongooseCollect.zsh / '' '' /var/log/org.churchofjesuschrist.log
#   or, with one log per script under a directory (Parameter 8):
#       sudo zsh mongooseCollect.zsh / '' '' '' '' '' '' /var/log/managed
#
####################################################################################################
#
# HISTORY
#
#   Version 0.0.1, 10-Nov-2026, Dan K. Snelson (@dan-snelson)
#       Initial release
#
#   Version 0.0.2, 14-Nov-2026, Dan K. Snelson (@dan-snelson)
#       Added Parameter 8: a per-script log directory, collected recursively (plain *.log files
#       and their rotated siblings; symlinks and hidden directories skipped; 500-file cap)
#
####################################################################################################



####################################################################################################
#
# Variables
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Global
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Copies, manifest and archive are readable by root only
umask 077

# Script Version
scriptVersion="0.0.2"

# Script Name (prefixes every log line)
scriptName="Mongoose Collect"

# Collection time: one epoch, so every time in the bundle agrees
collectionEpoch=$( date +%s )
timestamp=$( date -r "${collectionEpoch}" '+%Y-%m-%d-%H%M%S' )
collectionLocal=$( date -r "${collectionEpoch}" '+%Y-%m-%d %H:%M:%S %z' )
collectionUTC=$( date -u -r "${collectionEpoch}" '+%Y-%m-%dT%H:%M:%SZ' )

# Serial Number
serialNumber=$( ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformSerialNumber/{print $4}' )
[[ -z "${serialNumber}" ]] && serialNumber="unknown-serial"

# Self Service+ logs to Unified Logging, not a file; find it by bundle ID (organizations rename it)
selfServicePlusBundleID="com.jamf.selfserviceplus"
selfServicePlusApp=""
selfServicePlusVersion=""



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parameter 4: Organization's reverse-domain script log (for example, /var/log/org.churchofjesuschrist.log)
scriptLog="${4:-""}"

# Parameter 5: MDM agent log
mdmLog="${5:-"/var/log/jamf.log"}"

# Parameter 6: Output directory
outputDir="${6:-"/var/tmp"}"
[[ "${outputDir}" != "/" ]] && outputDir="${outputDir%/}"

# Parameter 7: Self Service+ log window, as passed to `log show --last` (for example, 1h, 1d or 7d)
selfServicePlusWindow="${7:-"36h"}"

# Parameter 8: Per-script log directory, collected recursively (for example, /var/log/managed)
scriptLogDir="${8:-""}"
while [[ "${scriptLogDir}" == ?*/ ]]; do scriptLogDir="${scriptLogDir%/}"; done
scriptLogDirMaxFiles=500                    # most *.log files collected from Parameter 8
scriptLogDirStatus="not set"                # set in pre-flight: "accepted" or "rejected: <reason>"
scriptLogDirFiles=0                         # *.log files discovered under Parameter 8
scriptLogDirOverflow=0                      # discovered beyond scriptLogDirMaxFiles, not collected



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Bundle Paths
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

bundleName="mongoose-${serialNumber}-${timestamp}"
stagingDir=""                               # set in pre-flight by mktemp -d (unpredictable name)
stagingCreated="false"
memberPrefix="${serialNumber}-${timestamp}"
manifestMember="${memberPrefix}-mongooseCollect-manifest.txt"
archivePath="${outputDir}/${bundleName}.zip"

# Collection results (collectedMembers and collectedSources are parallel arrays;
# collectedPaths holds each collected file's resolved path, so a file named twice is copied once)
typeset -a collectedMembers collectedSources collectedPaths missingRequired absentOptional
warningCount=0



####################################################################################################
#
# Functions
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Client-side Logging (stdout; also the script log, but only when it already exists)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    local logLine="${scriptName} ${scriptVersion}: $( date '+%Y-%m-%d %H:%M:%S %z' ) - ${1}"
    print -r -- "${logLine}"
    if [[ -n "${scriptLog}" && -f "${scriptLog}" ]]; then
        { print -r -- "${logLine}" >> "${scriptLog}" } 2>/dev/null
    fi
}

function preFlight() {
    updateScriptLog "[PRE-FLIGHT]      ${1}"
}

function notice() {
    updateScriptLog "[NOTICE]          ${1}"
}

function info() {
    updateScriptLog "[INFO]            ${1}"
}

function warning() {
    updateScriptLog "[WARNING]         ${1}"
    (( warningCount += 1 ))
}

function fatal() {
    updateScriptLog "[FATAL ERROR]     ${1}"
    removeStagingDir
    exit 1
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Remove the staging directory (only when this run created it)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function removeStagingDir() {
    if [[ "${stagingCreated}" == "true" && -n "${stagingDir}" && -d "${stagingDir}" ]]; then
        rm -rf "${stagingDir}"
    fi
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Choose a member name that no earlier member and not the manifest uses; sets REPLY
#   ${1}  member suffix (the member is named <serial>-<timestamp>-<suffix>, or
#         <serial>-<timestamp>-<n>-<suffix> when that name is taken, so the suffix
#         and its extension stay last)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function uniqueMemberName() {
    local preferredName="${memberPrefix}-${1}"
    local counter=2

    REPLY="${preferredName}"
    while [[ -e "${stagingDir}/${REPLY}" || "${REPLY}" == "${manifestMember}" ]]; do
        REPLY="${memberPrefix}-${counter}-${1}"
        (( counter += 1 ))
    done

    if [[ "${REPLY}" != "${preferredName}" ]]; then
        warning "Member name ${preferredName} is taken; using ${REPLY}"
    fi
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Copy one file into the staging directory
#   ${1}  source path
#   ${2}  member suffix (see uniqueMemberName)
#   ${3}  "required" or "optional"
#   ${4}  source as shown in logs and manifest (default: ${1})
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function collectFile() {
    local sourceFile="${1}"
    local memberName
    local sourceClass="${3}"
    local displaySource="${4:-${1}}"
    local destinationFile

    if [[ -f "${sourceFile}" ]]; then
        # The same file named twice (for example, by Parameters 4 and 5) is copied once
        if (( ${collectedPaths[(Ie)${sourceFile:A}]} )); then
            info "Already collected ${displaySource}; skipped the duplicate"
            return 0
        fi

        uniqueMemberName "${2}"
        memberName="${REPLY}"
        destinationFile="${stagingDir}/${memberName}"

        # -p keeps the source modification time, which Mongoose reads as time context
        if cp -p "${sourceFile}" "${destinationFile}"; then
            chmod 644 "${destinationFile}"
            collectedMembers+=( "${memberName}" )
            collectedSources+=( "${displaySource}" )
            collectedPaths+=( "${sourceFile:A}" )
            info "Collected ${displaySource} as ${memberName}"
            return 0
        fi
        warning "Unable to copy ${displaySource}"
        displaySource="${displaySource} (copy failed)"
    elif [[ "${sourceClass}" == "required" ]]; then
        warning "Required log not found: ${displaySource}"
    else
        info "Optional log not present: ${displaySource}"
    fi

    if [[ "${sourceClass}" == "required" ]]; then
        missingRequired+=( "${displaySource}" )
    else
        absentOptional+=( "${displaySource}" )
    fi
    return 1
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Copy every rotated sibling of a log (for example, system.log.0.gz), in numeric order
#   ${1}  base log path
#   ${2}  optional member-suffix prefix (for example, "a_" for a log nested under Parameter 8)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function collectRotated() {
    local baseFile="${1}"
    local suffixPrefix="${2:-""}"
    local rotatedFile

    for rotatedFile in "${baseFile}".*(N.n); do
        collectFile "${rotatedFile}" "${suffixPrefix}${rotatedFile:t}" "optional"
    done
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Copy every plain *.log under the script-log directory (Parameter 8), at any depth, with its
# rotated siblings; sets REPLY to the number of *.log files collected and returns 1 when none
#   **/ does not follow symlinked directories, the (.) qualifier keeps plain files only (so
#   symlinked files are skipped), and hidden files and directories, such as this script's
#   staging directory, never match. Nothing is ever written under Parameter 8.
#   Member suffix: the path relative to Parameter 8 with / replaced by _ (a/x.log -> a_x.log)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function collectScriptLogDir() {
    local -a discoveredLogs
    local logFile relativePath suffixPrefix
    local collectedCount=0

    discoveredLogs=( "${scriptLogDir}"/**/*.log(N.) )
    scriptLogDirFiles=${#discoveredLogs}

    if (( scriptLogDirFiles == 0 )); then
        warning "Script-log directory '${scriptLogDir}' holds no plain *.log files"
        REPLY=0
        return 1
    fi

    if (( scriptLogDirFiles > scriptLogDirMaxFiles )); then
        scriptLogDirOverflow=$(( scriptLogDirFiles - scriptLogDirMaxFiles ))
        warning "Script-log directory '${scriptLogDir}' holds ${scriptLogDirFiles} *.log files; collecting the first ${scriptLogDirMaxFiles} and skipping ${scriptLogDirOverflow}"
        absentOptional+=( "${scriptLogDirOverflow} *.log file(s) under ${scriptLogDir} beyond the ${scriptLogDirMaxFiles}-file cap" )
        discoveredLogs=( "${(@)discoveredLogs[1,scriptLogDirMaxFiles]}" )
    fi

    info "Collecting ${#discoveredLogs} *.log file(s) from script-log directory '${scriptLogDir}'"

    for logFile in "${discoveredLogs[@]}"; do
        relativePath="${logFile#"${scriptLogDir}/"}"
        suffixPrefix=""
        [[ "${relativePath}" == */* ]] && suffixPrefix="${${relativePath:h}//\//_}_"
        if collectFile "${logFile}" "${suffixPrefix}${logFile:t}" "optional"; then
            (( collectedCount += 1 ))
        fi
        collectRotated "${logFile}" "${suffixPrefix}"
    done

    REPLY="${collectedCount}"
    (( collectedCount > 0 ))
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Find Self Service+ in /Applications by bundle ID; sets selfServicePlusApp and selfServicePlusVersion
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function findSelfServicePlus() {
    local appPath infoPlist bundleID

    for appPath in /Applications/*.app(N/); do
        infoPlist="${appPath}/Contents/Info.plist"
        [[ -f "${infoPlist}" ]] || continue
        bundleID=$( /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${infoPlist}" 2>/dev/null )
        if [[ "${bundleID}" == "${selfServicePlusBundleID}" ]]; then
            selfServicePlusApp="${appPath}"
            selfServicePlusVersion=$( /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${infoPlist}" 2>/dev/null )
            return 0
        fi
    done
    return 1
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Export Self Service+ Unified Logging entries into the staging directory
#   (`log` is a Zsh builtin, so call /usr/bin/log by path)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function collectSelfServicePlusLog() {
    local memberName destinationFile
    local logPredicate="subsystem BEGINSWITH \"${selfServicePlusBundleID}\""
    local displaySource="log show --info --predicate '${logPredicate}' --last ${selfServicePlusWindow} --style compact"

    uniqueMemberName "selfserviceplus.log"
    memberName="${REPLY}"
    destinationFile="${stagingDir}/${memberName}"

    if /usr/bin/log show --info --predicate "${logPredicate}" --last "${selfServicePlusWindow}" --style compact > "${destinationFile}"; then
        chmod 644 "${destinationFile}"
        collectedMembers+=( "${memberName}" )
        collectedSources+=( "${displaySource}" )
        info "Collected Self Service+ entries (last ${selfServicePlusWindow}) as ${memberName}"
        return 0
    fi

    rm -f "${destinationFile}"
    warning "Unable to export Self Service+ entries from Unified Logging"
    absentOptional+=( "${displaySource} (export failed)" )
    return 1
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Write the collection manifest (no hostname, usernames or IP addresses)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function writeManifest() {
    local manifestFile="${stagingDir}/${manifestMember}"
    local timeZone bootEpoch bootUTC modelIdentifier osVersion osBuild
    local memberIndex memberFile memberBytes memberModified memberHash listItem

    timeZone=$( readlink /etc/localtime 2>/dev/null )
    timeZone="${timeZone#*zoneinfo/}"
    [[ -z "${timeZone}" ]] && timeZone="unknown"

    # kern.boottime prints "{ sec = <epoch>, usec = <microseconds> } <date>"
    bootEpoch=$( sysctl -n kern.boottime 2>/dev/null | awk -F'[ ,]+' '{ print $4 }' )
    if [[ "${bootEpoch}" == <-> ]]; then
        bootUTC=$( date -u -r "${bootEpoch}" '+%Y-%m-%dT%H:%M:%SZ' )
    else
        bootUTC="unknown"
    fi

    modelIdentifier=$( sysctl -n hw.model 2>/dev/null )
    osVersion=$( sw_vers -productVersion 2>/dev/null )
    osBuild=$( sw_vers -buildVersion 2>/dev/null )

    {
        print -r -- "Mongoose Collect manifest"
        print -r -- "Script version: ${scriptVersion}"
        print -r -- "Collection time (local): ${collectionLocal}"
        print -r -- "Collection time (UTC): ${collectionUTC}"
        print -r -- "Collection epoch: ${collectionEpoch}"
        print -r -- "Time zone: ${timeZone}"
        print -r -- "Serial number: ${serialNumber}"
        print -r -- "Model identifier: ${modelIdentifier:-unknown}"
        print -r -- "macOS: ${osVersion:-unknown} (${osBuild:-unknown})"
        print -r -- "Boot time (UTC): ${bootUTC}"
        print -r -- "Script log (Parameter 4): ${scriptLog:-not set}"
        if [[ "${scriptLogDirStatus}" == rejected:* ]]; then
            print -r -- "Script-log directory (Parameter 8): ${scriptLogDir} (${scriptLogDirStatus})"
        else
            print -r -- "Script-log directory (Parameter 8): ${scriptLogDir:-not set}"
        fi
        if (( scriptLogDirOverflow )); then
            print -r -- "Script-log files discovered: ${scriptLogDirFiles} (cap ${scriptLogDirMaxFiles}; ${scriptLogDirOverflow} not collected)"
        else
            print -r -- "Script-log files discovered: ${scriptLogDirFiles}"
        fi
        print -r -- "MDM agent log (Parameter 5): ${mdmLog}"
        print -r -- "Self Service+ log window (Parameter 7): ${selfServicePlusWindow}"
        if [[ -n "${selfServicePlusApp}" ]]; then
            print -r -- "Self Service+: ${selfServicePlusApp} (${selfServicePlusVersion:-unknown version})"
        else
            print -r -- "Self Service+: not installed"
        fi
        print -r -- ""
        print -r -- "Logs were copied while live; a truncated last line is a collection artifact."
        print -r -- "Modified is the source file's modification time, kept by cp -p."
        print -r -- "Self Service+ entries are exported with log show: Modified is export time, and"
        print -r -- "compact style prints local time without a UTC offset (see Time zone)."
        print -r -- "SHA-256 is of the member as archived."
        print -r -- "Parameter 8 members are named by their path under that directory, with / as _;"
        print -r -- "source gives each member's original path."
        print -r -- ""
        print -r -- "Members"
        printf '%s\t%s\t%s\t%s\t%s\n' "member" "bytes" "modified" "sha256" "source"
        for (( memberIndex = 1; memberIndex <= ${#collectedMembers}; memberIndex++ )); do
            memberFile="${stagingDir}/${collectedMembers[memberIndex]}"
            memberBytes=$( stat -f '%z' "${memberFile}" )
            memberModified=$( stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S%z' "${memberFile}" )
            memberHash=$( shasum -a 256 "${memberFile}" | awk '{ print $1 }' )
            printf '%s\t%s\t%s\t%s\t%s\n' "${collectedMembers[memberIndex]}" "${memberBytes}" "${memberModified}" "${memberHash}" "${collectedSources[memberIndex]}"
        done
        print -r -- ""
        print -r -- "Required logs missing"
        if (( ${#missingRequired} )); then
            for listItem in "${missingRequired[@]}"; do print -r -- "- ${listItem}"; done
        else
            print -r -- "- none"
        fi
        print -r -- ""
        print -r -- "Optional logs not collected"
        if (( ${#absentOptional} )); then
            for listItem in "${absentOptional[@]}"; do print -r -- "- ${listItem}"; done
        else
            print -r -- "- none"
        fi
    } > "${manifestFile}"

    chmod 644 "${manifestFile}"
}



####################################################################################################
#
# Pre-flight Checks
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Logging Preamble
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "${scriptName} (${scriptVersion}): initiating …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $( id -u ) -ne 0 ]]; then
    fatal "This script must be run as root; exiting."
fi
preFlight "Running as root; proceeding …"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Script log
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -z "${scriptLog}" ]]; then
    preFlight "Parameter 4 (reverse-domain script log) not set; logging to stdout only"
elif [[ ! -f "${scriptLog}" ]]; then
    preFlight "Script log '${scriptLog}' not found; logging to stdout only (it will not be created)"
else
    preFlight "Script log '${scriptLog}' exists; appending log entries to it"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Script-log directory (Parameter 8)
#   An absolute path to an existing directory, other than /; read only, never written
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -z "${scriptLogDir}" ]]; then
    preFlight "Parameter 8 (script-log directory) not set; skipping per-script logs"
elif [[ "${scriptLogDir}" != /* ]]; then
    scriptLogDirStatus="rejected: not an absolute path"
elif [[ "${scriptLogDir:A}" == "/" ]]; then
    scriptLogDirStatus="rejected: the root directory"
elif [[ ! -d "${scriptLogDir}" ]]; then
    scriptLogDirStatus="rejected: not an existing directory"
else
    scriptLogDirStatus="accepted"
    preFlight "Script-log directory '${scriptLogDir}' exists; collecting up to ${scriptLogDirMaxFiles} plain *.log files at any depth"
fi

if [[ "${scriptLogDirStatus}" == rejected:* ]]; then
    warning "Parameter 8 '${scriptLogDir}' ${scriptLogDirStatus}; skipping per-script logs"
    missingRequired+=( "script-log directory (Parameter 8 '${scriptLogDir}' ${scriptLogDirStatus})" )
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Self Service+ log window
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${selfServicePlusWindow}" != <->[mhd] ]]; then
    preFlight "Parameter 7 '${selfServicePlusWindow}' is not <number>m, h or d; using 36h"
    selfServicePlusWindow="36h"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Output directory
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -d "${outputDir}" || ! -w "${outputDir}" ]]; then
    fatal "Output directory '${outputDir}' is missing or not writable; exiting."
fi

# mktemp -d makes a new, unpredictable directory with mode 700 and never reuses an existing path
if ! stagingDir=$( mktemp -d "${outputDir}/.${bundleName}.XXXXXX" ); then
    stagingDir=""
    fatal "Unable to create a staging directory in '${outputDir}'; exiting."
fi
stagingCreated="true"
preFlight "Created staging directory '${stagingDir}'"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Complete
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

preFlight "Complete!"



####################################################################################################
#
# Program
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Required: system.log, MDM agent log, organization script logs (Parameter 4, Parameter 8 or both)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Gathering required logs …"

collectFile "/var/log/system.log" "system.log" "required"
collectRotated "/var/log/system.log"

collectFile "${mdmLog}" "${mdmLog:t}" "required"
collectRotated "${mdmLog}"

# Either parameter meets the script-log requirement; Parameter 4 is required only on its own
scriptLogsCollected=0

if [[ -n "${scriptLog}" ]]; then
    if [[ "${scriptLogDirStatus}" == "accepted" ]]; then
        scriptLogClass="optional"
    else
        scriptLogClass="required"
    fi
    collectFile "${scriptLog}" "${scriptLog:t}" "${scriptLogClass}" && (( scriptLogsCollected += 1 ))
    collectRotated "${scriptLog}"
fi

if [[ "${scriptLogDirStatus}" == "accepted" ]]; then
    collectScriptLogDir
    (( scriptLogsCollected += REPLY ))
fi

if [[ -z "${scriptLog}" && -z "${scriptLogDir}" ]]; then
    warning "Parameters 4 and 8 not set; bundle lacks the organization's script logs"
    missingRequired+=( "organization script logs (Parameters 4 and 8 not set)" )
elif [[ "${scriptLogDirStatus}" == "accepted" ]] && (( scriptLogsCollected == 0 )); then
    warning "Neither Parameter 4 nor Parameter 8 yielded a script log"
    missingRequired+=( "organization script logs (no file from Parameter 4 '${scriptLog:-not set}' or Parameter 8 '${scriptLogDir}')" )
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Optional: install.log and component logs
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Gathering optional logs …"

collectFile "/var/log/install.log" "install.log" "optional"
collectRotated "/var/log/install.log"

# App Auto-Patch 4
collectFile "/Library/Application Support/AppAutoPatch/logs/aap.log" "aap4.log" "optional"

# App Auto-Patch 3
collectFile "/Library/Management/AppAutoPatch/logs/aap.log" "aap.log" "optional"
collectFile "/Library/Management/AppAutoPatch/logs/aap_verbose.log" "aap_verbose.log" "optional"

# Endpoint privilege management (BeyondTrust EPM)
collectFile "/var/log/defendpoint/audit.log" "defendpoint.audit.log" "optional"

# Jamf Pro Self Service+ (Unified Logging; system-wide, so no console user is needed)
if findSelfServicePlus; then
    info "Found Self Service+ ${selfServicePlusVersion:-(unknown version)} at ${selfServicePlusApp}"
    collectSelfServicePlusLog
else
    info "Self Service+ not installed; skipped Self Service+ logs"
    absentOptional+=( "Self Service+ logs (no app with bundle ID ${selfServicePlusBundleID} in /Applications)" )
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Collection manifest
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Writing collection manifest …"
writeManifest
info "Wrote ${manifestMember}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Compress gathered files (flat members; zip keeps each member's modification time)
#   Build and test the archive inside the private staging directory, then publish it with
#   link(1): link(2) fails when the destination exists as a file, directory or symlink, so a
#   path planted in a shared output directory is never replaced, updated or followed. Every
#   failure removes only this run's staging directory.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Compressing gathered files …"

stagedArchive="${stagingDir}/${bundleName}.zip"
stagedMembers=( "${stagingDir}"/*(N.) )     # expanded before the staged archive exists

if ! zip -q -j "${stagedArchive}" "${stagedMembers[@]}"; then
    fatal "Unable to create '${stagedArchive}'; exiting."
fi

if ! unzip -tq "${stagedArchive}" > /dev/null; then
    fatal "Integrity test failed for '${stagedArchive}'; exiting."
fi

chmod 600 "${stagedArchive}"

if ! link "${stagedArchive}" "${archivePath}"; then
    fatal "Unable to publish '${archivePath}'; a file, directory or link may already use that path; exiting."
fi

removeStagingDir

archiveBytes=$( stat -f '%z' "${archivePath}" )
archiveHash=$( shasum -a 256 "${archivePath}" | awk '{ print $1 }' )

info "Archive: ${archivePath}"
info "Members: $(( ${#collectedMembers} + 1 )) (including manifest)"
info "Size: ${archiveBytes} bytes"
info "SHA-256: ${archiveHash}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Exit
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if (( ${#missingRequired} )); then
    warning "Bundle is incomplete for a full Mongoose audit; missing: ${(j:, :)missingRequired}"
fi

notice "Complete with ${warningCount} warning(s); transfer '${archivePath}' for analysis"
exit 0
