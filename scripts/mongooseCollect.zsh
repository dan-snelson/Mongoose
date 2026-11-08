#!/bin/zsh --no-rcs
####################################################################################################
#
# ABOUT
#
#   Mongoose Collect
#
#   Gathers the client-side logs a full Mongoose audit reads into one flat .zip archive:
#   system.log, the MDM agent log and the organization's reverse-domain script log, plus
#   install.log, App Auto-Patch, EPM audit and Jamf Pro Self Service logs when present, and a
#   collection manifest (collection time with offset, macOS build, boot time, serial number, and
#   per-member size, modification time and SHA-256).
#
#   Transferring the .zip is out of scope; the archive stays in the output directory.
#
#   Run as root, for example from a Jamf Pro policy, or locally:
#       sudo zsh mongooseCollect.zsh / '' '' /var/log/org.churchofjesuschrist.log
#
####################################################################################################
#
# HISTORY
#
#   Version 1.0.0, 07-Nov-2026, Dan K. Snelson (@dan-snelson)
#       Initial release
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
scriptVersion="1.0.0"

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

# Currently Logged-in User
loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Jamf Pro Script Parameters
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# Parameter 4: Organization's reverse-domain script log (for example, /var/log/org.churchofjesuschrist.log)
scriptLog="${4:-""}"

# Parameter 5: MDM agent log
mdmLog="${5:-"/var/log/jamf.log"}"

# Parameter 6: Output directory
outputDir="${6:-"/var/tmp"}"
[[ "${outputDir}" != "/" ]] && outputDir="${outputDir%/}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Bundle Paths
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

bundleName="mongoose-${serialNumber}-${timestamp}"
stagingDir="${outputDir}/${bundleName}"
stagingCreated="false"
memberPrefix="${serialNumber}-${timestamp}"
manifestMember="${memberPrefix}-mongooseCollect-manifest.txt"
archivePath="${outputDir}/${bundleName}.zip"

# Collection results (collectedMembers and collectedSources are parallel arrays)
typeset -a collectedMembers collectedSources missingRequired absentOptional
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
# Copy one file into the staging directory
#   ${1}  source path
#   ${2}  member suffix (the member is named <serial>-<timestamp>-<suffix>)
#   ${3}  "required" or "optional"
#   ${4}  source as shown in logs and manifest (default: ${1})
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function collectFile() {
    local sourceFile="${1}"
    local memberName="${memberPrefix}-${2}"
    local sourceClass="${3}"
    local displaySource="${4:-${1}}"
    local destinationFile="${stagingDir}/${memberName}"

    if [[ -f "${sourceFile}" ]]; then
        # -p keeps the source modification time, which Mongoose reads as time context
        if cp -p "${sourceFile}" "${destinationFile}"; then
            chmod 644 "${destinationFile}"
            collectedMembers+=( "${memberName}" )
            collectedSources+=( "${displaySource}" )
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
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

function collectRotated() {
    local baseFile="${1}"
    local rotatedFile

    for rotatedFile in "${baseFile}".*(N.n); do
        collectFile "${rotatedFile}" "${rotatedFile:t}" "optional"
    done
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
        print -r -- "MDM agent log (Parameter 5): ${mdmLog}"
        print -r -- ""
        print -r -- "Logs were copied while live; a truncated last line is a collection artifact."
        print -r -- "Modified is the source file's modification time, kept by cp -p."
        print -r -- "SHA-256 is of the member as archived."
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
# Pre-flight Check: Output directory
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ ! -d "${outputDir}" || ! -w "${outputDir}" ]]; then
    fatal "Output directory '${outputDir}' is missing or not writable; exiting."
fi

if ! mkdir "${stagingDir}"; then
    fatal "Unable to create staging directory '${stagingDir}'; exiting."
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
# Required: system.log, MDM agent log, reverse-domain script log
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Gathering required logs …"

collectFile "/var/log/system.log" "system.log" "required"
collectRotated "/var/log/system.log"

collectFile "${mdmLog}" "${mdmLog:t}" "required"
collectRotated "${mdmLog}"

if [[ -n "${scriptLog}" ]]; then
    collectFile "${scriptLog}" "${scriptLog:t}" "required"
    collectRotated "${scriptLog}"
else
    warning "Parameter 4 not set; bundle lacks the reverse-domain script log"
    missingRequired+=( "reverse-domain script log (Parameter 4 not set)" )
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

# Jamf Pro Self Service (console user); the manifest shows "~", never the username
if [[ -n "${loggedInUser}" && "${loggedInUser}" != "loginwindow" ]]; then
    userHome=$( dscl . -read "/Users/${loggedInUser}" NFSHomeDirectory 2>/dev/null | awk -F': ' '/NFSHomeDirectory/ { print $2 }' )
    if [[ -n "${userHome}" ]]; then
        collectFile "${userHome}/Library/Logs/JAMF/selfservice.log" "selfservice.log" "optional" "~/Library/Logs/JAMF/selfservice.log"
        collectFile "${userHome}/Library/Logs/JAMF/selfservice_debug.log" "selfservice_debug.log" "optional" "~/Library/Logs/JAMF/selfservice_debug.log"
    else
        info "Console user's home directory not found; skipped Self Service logs"
        absentOptional+=( "~/Library/Logs/JAMF/selfservice*.log (home directory not found)" )
    fi
else
    info "No console user; skipped Self Service logs"
    absentOptional+=( "~/Library/Logs/JAMF/selfservice*.log (no console user)" )
fi



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Collection manifest
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Writing collection manifest …"
writeManifest
info "Wrote ${manifestMember}"



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Compress gathered files (flat members; zip keeps each member's modification time)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

notice "Compressing gathered files …"

if ! zip -q -j "${archivePath}" "${stagingDir}"/*(N.); then
    rm -f "${archivePath}"
    fatal "Unable to create '${archivePath}'; exiting."
fi

if ! unzip -tq "${archivePath}" > /dev/null; then
    rm -f "${archivePath}"
    fatal "Integrity test failed for '${archivePath}'; exiting."
fi

chmod 600 "${archivePath}"
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
