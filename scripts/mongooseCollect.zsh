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
#   The MDM agent log (Parameter 5) is a file path, or a Unified Logging predicate exported with
#   log show. Left empty, the MDM vendor is detected from the enrollment profile: Jamf Pro and
#   undetected Macs use /var/log/jamf.log; a recognized vendor whose agent log source is not
#   known is recorded as missing (set Parameter 5). The enrollment server address is never
#   printed, logged or written to the manifest.
#
#   Transferring the .zip is out of scope; the archive stays in the output directory.
#   Mongoose reads the archive off the Mac; nothing here runs an agent or LLM.
#
#   Run as root, for example from a Jamf Pro policy, or locally:
#       sudo zsh mongooseCollect.zsh / '' '' /var/log/com.example.it.log
#   or, with one log per script under a directory (Parameter 8):
#       sudo zsh mongooseCollect.zsh / '' '' '' '' '' '' /var/log/managed
#   or, with an MDM agent that logs only to Unified Logging (Parameter 5 as a predicate):
#       sudo zsh mongooseCollect.zsh / '' '' /var/log/com.example.it.log 'process == "<mdm-agent-process>"'
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
#       and their rotated siblings; symlinks and hidden directories skipped; 500-file cap on
#       *.log and rotated files combined); never written: a Parameter 4 log under it is collected
#       but not appended to, and an output directory at or under it is refused
#       Rotated siblings of every log are limited to <log>.<n>, <log>.<n>.gz and <log>.<n>.bz2
#
#   Version 0.0.3, 14-Nov-2026, Dan K. Snelson (@dan-snelson)
#       Parameter 5 accepts a Unified Logging predicate as well as a file path; the predicate is
#       exported with log show (Parameter 7 window) as the required MDM agent log, and an export
#       with no entries is recorded as missing (issue #5)
#       Parameter 5 empty: the MDM vendor is detected from the enrollment profile (ported from
#       Mac Health Check); Jamf Pro and undetected Macs use /var/log/jamf.log, and a recognized
#       vendor with no known agent log source is recorded as missing; the enrollment server
#       address is never printed, logged or written to the manifest
#       Parameter 7 renamed "Unified Logging window"; it applies to both Unified Logging exports
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
scriptVersion="0.0.3"

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

# Parameter 4: Organization's reverse-domain script log (for example, /var/log/com.example.it.log)
scriptLog="${4:-""}"

# Parameter 5: MDM agent log: an absolute file path (starts with /) or a Unified Logging predicate;
# empty: detected from the enrollment profile (see detectMdmVendor and the MDM agent log pre-flight)
mdmLogParam="${5:-""}"
mdmLogDefault="/var/log/jamf.log"           # Jamf Pro, and the fallback when no vendor is detected
mdmLogPredicateMaxLength=1024               # longest Parameter 5 predicate accepted
mdmVendor=""                                # set by detectMdmVendor (vendor name only)
mdmVendorReason=""                          # set by detectMdmVendor when no vendor is recognized
mdmVendorStatus="not checked (Parameter 5 set)"
mdmLogSource=""                             # set in pre-flight: file, predicate, unknown or rejected
mdmLogFile=""
mdmLogPredicate=""
mdmLogRejectReason=""

# Parameter 6: Output directory
outputDir="${6:-"/var/tmp"}"
[[ "${outputDir}" != "/" ]] && outputDir="${outputDir%/}"

# Parameter 7: Unified Logging window (Self Service+ and a Parameter 5 predicate), as passed to
# `log show --last` (for example, 1h, 1d or 7d)
unifiedLogWindow="${7:-"36h"}"

# Parameter 8: Per-script log directory, collected recursively (for example, /var/log/managed)
scriptLogDir="${8:-""}"
while [[ "${scriptLogDir}" == ?*/ ]]; do scriptLogDir="${scriptLogDir%/}"; done
scriptLogDirMaxFiles=500                    # most files collected from Parameter 8 (*.log and rotated combined)
scriptLogDirStatus="not set"                # set in pre-flight: "accepted" or "rejected: <reason>"
scriptLogDirLogs=0                          # plain *.log files discovered under Parameter 8
scriptLogDirFiles=0                         # files discovered under Parameter 8: *.log plus rotated siblings
scriptLogDirOverflow=0                      # discovered beyond scriptLogDirMaxFiles, not collected

# Parameter 8 is never written: when the script log (Parameter 4) resolves inside it, the log is
# still collected but never appended to (:A resolves symlinks; set before the first log line)
scriptLogAppend="true"
if [[ -n "${scriptLog}" && "${scriptLogDir}" == /* && -d "${scriptLogDir}" && "${scriptLogDir:A}" != "/" \
    && "${scriptLog:A}" == "${scriptLogDir:A}"/* ]]; then
    scriptLogAppend="false"
fi



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
# Client-side Logging (stdout; also the script log, but only when it already exists and is
# outside Parameter 8)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function updateScriptLog() {
    local logLine="${scriptName} ${scriptVersion}: $( date '+%Y-%m-%d %H:%M:%S %z' ) - ${1}"
    print -r -- "${logLine}"
    if [[ "${scriptLogAppend}" == "true" && -n "${scriptLog}" && -f "${scriptLog}" ]]; then
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
# List the rotated siblings of a log, in numeric order; sets reply
#   ${1}  base log path
#   Accepts only the names newsyslog writes: <log>.<n>, <log>.<n>.gz and <log>.<n>.bz2 (for
#   example, system.log.0.gz). The (.) qualifier keeps plain files only, so symlinks and other
#   names, such as <log>.bak, never match.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function rotatedSiblings() {
    reply=( "${1}".<->(|.gz|.bz2)(N.n) )
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Copy every rotated sibling of a log (see rotatedSiblings), in numeric order
#   ${1}  base log path
#   ${2}  optional member-suffix prefix (for example, "a_" for a log nested under Parameter 8)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function collectRotated() {
    local baseFile="${1}"
    local suffixPrefix="${2:-""}"
    local -a rotatedFiles
    local rotatedFile

    rotatedSiblings "${baseFile}"
    rotatedFiles=( "${reply[@]}" )

    for rotatedFile in "${rotatedFiles[@]}"; do
        collectFile "${rotatedFile}" "${suffixPrefix}${rotatedFile:t}" "optional"
    done
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Copy every plain *.log under the script-log directory (Parameter 8), at any depth, with its
# rotated siblings (see rotatedSiblings); sets REPLY to the number of files collected and
# returns 1 when none
#   **/ does not follow symlinked directories, the (.) qualifier keeps plain files only (so
#   symlinked files are skipped), and hidden files and directories, such as this script's
#   staging directory, never match. Nothing is ever written under Parameter 8.
#   Cap: scriptLogDirMaxFiles counts every candidate, *.log and rotated combined; candidates
#   are listed each *.log followed by its rotated siblings, and those past the cap are skipped.
#   Member suffix: the path relative to Parameter 8 with / replaced by _ (a/x.log -> a_x.log)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function collectScriptLogDir() {
    local -a discoveredLogs candidateFiles candidateSuffixes
    local logFile rotatedFile relativePath suffixPrefix
    local candidateIndex
    local collectedCount=0

    discoveredLogs=( "${scriptLogDir}"/**/*.log(N.) )
    scriptLogDirLogs=${#discoveredLogs}

    if (( scriptLogDirLogs == 0 )); then
        warning "Script-log directory '${scriptLogDir}' holds no plain *.log files"
        REPLY=0
        return 1
    fi

    for logFile in "${discoveredLogs[@]}"; do
        relativePath="${logFile#"${scriptLogDir}/"}"
        suffixPrefix=""
        [[ "${relativePath}" == */* ]] && suffixPrefix="${${relativePath:h}//\//_}_"
        candidateFiles+=( "${logFile}" )
        candidateSuffixes+=( "${suffixPrefix}${logFile:t}" )
        rotatedSiblings "${logFile}"
        for rotatedFile in "${reply[@]}"; do
            candidateFiles+=( "${rotatedFile}" )
            candidateSuffixes+=( "${suffixPrefix}${rotatedFile:t}" )
        done
    done
    scriptLogDirFiles=${#candidateFiles}

    if (( scriptLogDirFiles > scriptLogDirMaxFiles )); then
        scriptLogDirOverflow=$(( scriptLogDirFiles - scriptLogDirMaxFiles ))
        warning "Script-log directory '${scriptLogDir}' holds ${scriptLogDirFiles} files (${scriptLogDirLogs} *.log plus rotated); collecting the first ${scriptLogDirMaxFiles} and skipping ${scriptLogDirOverflow}"
        absentOptional+=( "${scriptLogDirOverflow} file(s) under ${scriptLogDir} beyond the ${scriptLogDirMaxFiles}-file cap (base and rotated combined)" )
        candidateFiles=( "${(@)candidateFiles[1,scriptLogDirMaxFiles]}" )
        candidateSuffixes=( "${(@)candidateSuffixes[1,scriptLogDirMaxFiles]}" )
    fi

    info "Collecting ${#candidateFiles} file(s) from script-log directory '${scriptLogDir}'"

    for (( candidateIndex = 1; candidateIndex <= ${#candidateFiles}; candidateIndex++ )); do
        if collectFile "${candidateFiles[candidateIndex]}" "${candidateSuffixes[candidateIndex]}" "optional"; then
            (( collectedCount += 1 ))
        fi
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
# Detect the MDM vendor from the enrollment profile; sets mdmVendor (vendor name only) and returns
# 0, or sets mdmVendorReason and returns 1
#   Ported from Mac Health Check's MDM vendor detection (thanks, @TechTrekkie!): read
#   `profiles list -output stdout-xml` once, take the ServerURL of the com.apple.mdm payload
#   (its PayloadContent sorts before its PayloadType), reduce it to a lowercase host and match
#   the host on vendor substrings. The ServerURL and host are <mdm-url>: they stay in local
#   variables and are never printed, logged or written to the manifest.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function detectMdmVendor() {
    local profilesXML serverURL serverHost

    mdmVendor=""
    mdmVendorReason=""

    if ! profilesXML=$( profiles list -output stdout-xml 2>/dev/null ); then
        mdmVendorReason="profiles list failed"
        return 1
    fi

    # The ServerURL seen since the last PayloadType, printed only when that PayloadType is
    # com.apple.mdm; a ServerURL in any other payload is discarded
    serverURL=$( print -r -- "${profilesXML}" | awk '
        /<key>ServerURL<\/key>/   { wantURL = 1; if ($0 !~ /<string>/) next }
        wantURL && /<string>/     { url = $0; sub(/.*<string>/, "", url); sub(/<\/string>.*/, "", url); wantURL = 0; next }
        /<key>PayloadType<\/key>/ { wantType = 1; if ($0 !~ /<string>/) next }
        wantType && /<string>/    { wantType = 0; if ($0 ~ /<string>com\.apple\.mdm<\/string>/ && url != "") { print url; exit } url = "" }
    ' )

    if [[ -z "${serverURL}" ]]; then
        mdmVendorReason="no MDM enrollment profile found"
        return 1
    fi

    # Host only: drop the scheme, then any path, query or fragment, user info and port
    serverHost="${serverURL#*://}"
    serverHost="${serverHost%%[/?#]*}"
    serverHost="${serverHost##*@}"
    serverHost="${(L)serverHost%%:*}"

    case "${serverHost}" in
        *addigy* )          mdmVendor="Addigy" ;;
        *filewave* )        mdmVendor="FileWave" ;;
        *fleet* )           mdmVendor="Fleet" ;;
        *jamf* | *jss* )    mdmVendor="Jamf Pro" ;;
        *jumpcloud* )       mdmVendor="JumpCloud" ;;
        *kandji* )          mdmVendor="Kandji" ;;
        *microsoft* )       mdmVendor="Microsoft Intune" ;;
        *mosyle* )          mdmVendor="Mosyle" ;;
        * )
            mdmVendorReason="enrollment server matches no known vendor"
            return 1
            ;;
    esac

    return 0
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Export Unified Logging entries into the staging directory
#   ${1}  predicate, passed to log show as one argument (never evaluated by the shell)
#   ${2}  member suffix (see uniqueMemberName)
#   ${3}  label for log lines and the missing-log entry (for example, "Self Service+")
#   ${4}  "required" or "optional"; a required export with no entries in the window is kept
#         but also recorded as missing, since a mistyped predicate matches nothing
#   (`log` is a Zsh builtin, so call /usr/bin/log by path)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function collectUnifiedLog() {
    local logPredicate="${1}"
    local memberSuffix="${2}"
    local logLabel="${3}"
    local sourceClass="${4}"
    local memberName destinationFile
    local displaySource="log show --info --predicate '${logPredicate}' --last ${unifiedLogWindow} --style compact"

    uniqueMemberName "${memberSuffix}"
    memberName="${REPLY}"
    destinationFile="${stagingDir}/${memberName}"

    if /usr/bin/log show --info --predicate "${logPredicate}" --last "${unifiedLogWindow}" --style compact > "${destinationFile}"; then
        chmod 644 "${destinationFile}"
        collectedMembers+=( "${memberName}" )
        collectedSources+=( "${displaySource}" )
        info "Collected ${logLabel} entries (last ${unifiedLogWindow}) as ${memberName}"

        # Compact style starts each entry with a date; a header-only export matched nothing
        if [[ "${sourceClass}" == "required" ]] && ! grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2} ' "${destinationFile}"; then
            warning "${logLabel} export matched no entries in the last ${unifiedLogWindow}; check the predicate"
            missingRequired+=( "${logLabel} (log show matched no entries in the last ${unifiedLogWindow})" )
        fi
        return 0
    fi

    rm -f "${destinationFile}"
    warning "Unable to export ${logLabel} entries from Unified Logging"
    if [[ "${sourceClass}" == "required" ]]; then
        missingRequired+=( "${displaySource} (export failed)" )
    else
        absentOptional+=( "${displaySource} (export failed)" )
    fi
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
            print -r -- "Script-log files discovered: ${scriptLogDirFiles} (${scriptLogDirLogs} *.log plus rotated); cap ${scriptLogDirMaxFiles}; ${scriptLogDirOverflow} not collected"
        else
            print -r -- "Script-log files discovered: ${scriptLogDirFiles} (${scriptLogDirLogs} *.log plus rotated)"
        fi
        if [[ "${mdmLogSource}" == "rejected" ]]; then
            print -r -- "MDM agent log (Parameter 5): predicate not shown (rejected: ${mdmLogRejectReason})"
        else
            print -r -- "MDM agent log (Parameter 5): ${mdmLogParam:-not set}"
        fi
        print -r -- "MDM vendor: ${mdmVendorStatus}"
        case "${mdmLogSource}" in
            file )      print -r -- "MDM agent log source: file ${mdmLogFile}" ;;
            predicate ) print -r -- "MDM agent log source: Unified Logging predicate" ;;
            unknown )   print -r -- "MDM agent log source: not known (set Parameter 5)" ;;
            rejected )  print -r -- "MDM agent log source: none (Parameter 5 rejected)" ;;
        esac
        print -r -- "Unified Logging window (Parameter 7): ${unifiedLogWindow}"
        if [[ -n "${selfServicePlusApp}" ]]; then
            print -r -- "Self Service+: ${selfServicePlusApp} (${selfServicePlusVersion:-unknown version})"
        else
            print -r -- "Self Service+: not installed"
        fi
        print -r -- ""
        print -r -- "Logs were copied while live; a truncated last line is a collection artifact."
        print -r -- "Modified is the source file's modification time, kept by cp -p."
        print -r -- "Unified Logging exports (Self Service+, and the MDM agent log when Parameter 5 is a"
        print -r -- "predicate) are made with log show; source gives the command: Modified is export time,"
        print -r -- "and compact style prints local time without a UTC offset (see Time zone)."
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
elif [[ "${scriptLogAppend}" != "true" ]]; then
    preFlight "Script log '${scriptLog}' is inside Parameter 8 '${scriptLogDir}'; logging to stdout only (still collected)"
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
    preFlight "Script-log directory '${scriptLogDir}' exists; collecting up to ${scriptLogDirMaxFiles} files (plain *.log at any depth plus rotated siblings)"
fi

# A rejected Parameter 8 is only a warning here (the manifest prints the reason); the script-log
# requirement is judged after collection, when Parameter 4 may still meet it
if [[ "${scriptLogDirStatus}" == rejected:* ]]; then
    warning "Parameter 8 '${scriptLogDir}' ${scriptLogDirStatus}; skipping per-script logs"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Unified Logging window (Parameter 7)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ "${unifiedLogWindow}" != <->[mhd] ]]; then
    preFlight "Parameter 7 '${unifiedLogWindow}' is not <number>m, h or d; using 36h"
    unifiedLogWindow="36h"
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: MDM agent log (Parameter 5)
#   Set: a value starting with / is a file; any other value is a Unified Logging predicate,
#   rejected when it holds control characters or is longer than mdmLogPredicateMaxLength
#   (log show itself rejects bad syntax). Empty: detect the MDM vendor (see detectMdmVendor);
#   Jamf Pro and undetected Macs use mdmLogDefault. The requirement is judged during collection.
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ -n "${mdmLogParam}" ]]; then
    if [[ "${mdmLogParam}" == /* ]]; then
        mdmLogSource="file"
        mdmLogFile="${mdmLogParam}"
        preFlight "Parameter 5 is a file path; collecting MDM agent log '${mdmLogFile}'"
    elif [[ "${mdmLogParam}" == *[[:cntrl:]]* ]]; then
        mdmLogSource="rejected"
        mdmLogRejectReason="predicate contains control characters"
    elif (( ${#mdmLogParam} > mdmLogPredicateMaxLength )); then
        mdmLogSource="rejected"
        mdmLogRejectReason="predicate is longer than ${mdmLogPredicateMaxLength} characters"
    else
        mdmLogSource="predicate"
        mdmLogPredicate="${mdmLogParam}"
        preFlight "Parameter 5 is a Unified Logging predicate; exporting the MDM agent log with log show (last ${unifiedLogWindow})"
    fi
    if [[ "${mdmLogSource}" == "rejected" ]]; then
        warning "Parameter 5 rejected: ${mdmLogRejectReason}; skipping the MDM agent log"
    fi
else
    if detectMdmVendor; then
        mdmVendorStatus="${mdmVendor} (enrollment profile)"
        preFlight "Parameter 5 not set; detected MDM vendor ${mdmVendor} from the enrollment profile"

        # Agent log source per vendor; empty means not known (no guessed paths or predicates)
        case "${mdmVendor}" in
            "Jamf Pro" )
                mdmLogFile="${mdmLogDefault}"
                ;;
            "Mosyle" )
                # Logs only to Unified Logging; confirm the process or subsystem from a sanitized
                # log show sample before filling in mdmLogPredicate (issue #5)
                mdmLogPredicate=""
                ;;
        esac

        if [[ -n "${mdmLogFile}" ]]; then
            mdmLogSource="file"
            preFlight "Collecting ${mdmVendor} agent log '${mdmLogFile}'"
        elif [[ -n "${mdmLogPredicate}" ]]; then
            mdmLogSource="predicate"
            preFlight "Exporting the ${mdmVendor} agent log with log show (last ${unifiedLogWindow})"
        else
            mdmLogSource="unknown"
            warning "${mdmVendor} detected; its agent log source is not known; set Parameter 5 to a file path or Unified Logging predicate"
        fi
    else
        mdmVendorStatus="not detected"
        mdmLogSource="file"
        mdmLogFile="${mdmLogDefault}"
        preFlight "Parameter 5 not set; MDM vendor not detected (${mdmVendorReason}); collecting '${mdmLogFile}'"
    fi
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Pre-flight Check: Output directory
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -d "${outputDir}" || ! -w "${outputDir}" ]]; then
    fatal "Output directory '${outputDir}' is missing or not writable; exiting."
fi

# Parameter 8 is never written, so refuse an output directory at or under it before staging exists
if [[ "${scriptLogDirStatus}" == "accepted" ]] \
    && [[ "${outputDir:A}" == "${scriptLogDir:A}" || "${outputDir:A}" == "${scriptLogDir:A}"/* ]]; then
    fatal "Output directory '${outputDir}' is inside Parameter 8 '${scriptLogDir}', which is never written; exiting."
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

# MDM agent log: a file with its rotated siblings, or a Unified Logging export (see pre-flight)
case "${mdmLogSource}" in
    file )
        collectFile "${mdmLogFile}" "${mdmLogFile:t}" "required"
        collectRotated "${mdmLogFile}"
        ;;
    predicate )
        collectUnifiedLog "${mdmLogPredicate}" "mdm-agent.log" "MDM agent log" "required"
        ;;
    unknown )
        missingRequired+=( "MDM agent log (${mdmVendor} detected; agent log source not known; set Parameter 5 to a file path or Unified Logging predicate)" )
        ;;
    rejected )
        missingRequired+=( "MDM agent log (Parameter 5 rejected: ${mdmLogRejectReason})" )
        ;;
esac

# Parameters 4 and 8 are each collected as optional; the requirement is met when either yields
# at least one file, and a single missingRequired entry (naming both, with any Parameter 8
# rejection reason) is recorded only when neither does
scriptLogsCollected=0

if [[ -n "${scriptLog}" ]]; then
    collectFile "${scriptLog}" "${scriptLog:t}" "optional" && (( scriptLogsCollected += 1 ))
    collectRotated "${scriptLog}"
fi

if [[ "${scriptLogDirStatus}" == "accepted" ]]; then
    collectScriptLogDir
    (( scriptLogsCollected += REPLY ))
fi

if (( scriptLogsCollected == 0 )); then
    if [[ -z "${scriptLog}" && -z "${scriptLogDir}" ]]; then
        warning "Parameters 4 and 8 not set; bundle lacks the organization's script logs"
        missingRequired+=( "organization script logs (Parameters 4 and 8 not set)" )
    else
        scriptLogDirDetail="'${scriptLogDir:-not set}'"
        [[ "${scriptLogDirStatus}" == rejected:* ]] && scriptLogDirDetail+=" (${scriptLogDirStatus})"
        warning "Neither Parameter 4 nor Parameter 8 yielded a script log"
        missingRequired+=( "organization script logs (no file from Parameter 4 '${scriptLog:-not set}' or Parameter 8 ${scriptLogDirDetail})" )
    fi
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
    collectUnifiedLog "subsystem BEGINSWITH \"${selfServicePlusBundleID}\"" "selfserviceplus.log" "Self Service+" "optional"
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
