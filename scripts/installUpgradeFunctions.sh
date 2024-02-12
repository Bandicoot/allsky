#!/bin/bash

# Shell variables and functions used by the installation and upgrade scripts.
# This file is "source"d into others, and must be done AFTER source'ing variables.sh.


######################################### variables

# export to keep shellcheck quiet
	# The login installing Allsky
export ALLSKY_OWNER=$( id --group --name )
export ALLSKY_GROUP=${ALLSKY_OWNER}
export WEBSERVER_OWNER="www-data"
export WEBSERVER_GROUP="${WEBSERVER_OWNER}"

	# Central location for all master repository files.
export ALLSKY_REPO="${ALLSKY_HOME}/config_repo"
export REPO_WEBCONFIG_FILE="${ALLSKY_REPO}/${ALLSKY_WEBSITE_CONFIGURATION_NAME}.repo"
export REPO_SUDOERS_FILE="${ALLSKY_REPO}/sudoers.repo"
export ALLSKY_DEFINES_INC="allskyDefines.inc"
export REPO_WEBUI_DEFINES_FILE="${ALLSKY_REPO}/${ALLSKY_DEFINES_INC}.repo"
export REPO_LIGHTTPD_FILE="${ALLSKY_REPO}/lighttpd.conf.repo"
export REPO_AVI_FILE="${ALLSKY_REPO}/avahi-daemon.conf.repo"
export REPO_OPTIONS_FILE="${ALLSKY_REPO}/$( basename "${OPTIONS_FILE}" ).repo"
export REPO_ENV_FILE="${ALLSKY_REPO}/$( basename "${ALLSKY_ENV}" ).repo"
export REPO_WEBSITE_CONFIGURATION_FILE="${ALLSKY_REPO}/${ALLSKY_WEBSITE_CONFIGURATION_NAME}.repo"

##### Information on prior Allsky versions
	# Location of old-style WebUI and Website.
export OLD_WEBUI_LOCATION="/var/www/html"
export OLD_WEBSITE_LOCATION="${OLD_WEBUI_LOCATION}/allsky"
	# Directory of prior version of Allsky, if it exists.
export PRIOR_ALLSKY_DIR="$( dirname "${ALLSKY_HOME}" )/${ALLSKY_INSTALL_DIR}-OLD"
	# Prior "config" directory, if it exists.
export PRIOR_CONFIG_DIR="${PRIOR_ALLSKY_DIR}/$( basename "${ALLSKY_CONFIG}" )"
export PRIOR_REMOTE_WEBSITE_CONFIGURATION_FILE="${PRIOR_CONFIG_DIR}/${ALLSKY_REMOTE_WEBSITE_CONFIGURATION_NAME}"
export PRIOR_PYTHON_VENV="${PRIOR_ALLSKY_DIR}/venv/lib"

	# Name of setting that determines version of Website config file.
export WEBSITE_CONFIG_VERSION="ConfigVersion"
	# Name of setting that holds the Allsky version.
export WEBSITE_ALLSKY_VERSION="config.AllskyVersion"

	# Location of prior files varies by release; this is most recent location.
export PRIOR_CONFIG_FILE="${PRIOR_CONFIG_DIR}/config.sh"
export PRIOR_FTP_FILE="${PRIOR_CONFIG_DIR}/ftp-settings.sh"

	# Location of lighttpd files.
export LIGHTTPD_LOG_DIR="/var/log/lighttpd"
export LIGHTTPD_LOG_FILE="${LIGHTTPD_LOG_DIR}/error.log"
export LIGHTTPD_CONFIG_FILE="/etc/lighttpd/lighttpd.conf"

# Other variables used below and are hear to centralize them.
export SWAP_CONFIG_FILE="/etc/dphys-swapfile"

######################################### functions

#####
# Display a header surrounded by stars.
function display_header() {
	local HEADER="${1}"
	local LEN
	((LEN = ${#HEADER} + 8))		# 8 for leading and trailing "*** "
	local STARS=""
	while [[ ${LEN} -gt 0 ]]; do
		STARS+="*"
		((LEN--))
	done
	echo
	echo "${STARS}"
	echo -e "*** ${HEADER} ***"
	echo "${STARS}"
	echo
}

#####
function calc_wt_size()
{
	local WT_WIDTH=$( tput cols )
	[[ ${WT_WIDTH} -gt 80 ]] && WT_WIDTH=80
	echo "${WT_WIDTH}"
}

#####
# Get a Git version, stripping any trailing newline.
# Return "" if none, or on error.
function get_Git_version() {
	local BRANCH="${1}"
	local PACKAGE="${2}"
	local VF="$( basename "${ALLSKY_VERSION_FILE}" )"
	local V="$( curl --show-error --silent "${GITHUB_RAW_ROOT}/${PACKAGE}/${BRANCH}/${VF}" | tr -d '\n\r' )"
	# "404" means the branch isn't found since all new branches have a version file.
	[[ ${V} != "404: Not Found" ]] && echo -n "${V}"
}


# For the version, if the last character of the argument passed is a "/",
# then append the file name from ${ALLSKY_VERSION_FILE}.
# We do this to limit the number of places that know the actual name of the file,
# in case we ever change it.

#####
# Get the version from a local file, if it exists.  If not, get from default file.
function get_version() {
	local F="${1}"
	if [[ -z ${F} ]]; then
		F="${ALLSKY_VERSION_FILE}"		# default
	else
		[[ ${F:1,-1} == "/" ]] && F+="$( basename "${ALLSKY_VERSION_FILE}" )"
	fi
	if [[ -f ${F} ]]; then
		# Sometimes the branch file will have both "master" and "dev" on two lines.
		local VALUE="$( head -1 "${F}" )"
		echo -n "${VALUE}" | tr -d '\n\r'
	fi
}


#####
# Get the branch using git.
function get_branch() {
	local H="${1:-${ALLSKY_HOME}}"
	echo "$( cd "${H}" || exit; git rev-parse --abbrev-ref HEAD )"
}


#####
# Get a shell variable's value.  The variable can have optional spaces and tabs before it.
# This function is useful when we can't "source" the file.
function get_variable() {
	local VARIABLE="${1}"
	local FILE="${2}"
	local LINE=""
	local SEARCH_STRING="^[ 	]*${VARIABLE}="
	if ! LINE="$( /bin/grep -E "${SEARCH_STRING}" "${FILE}" 2>/dev/null )" ; then
		return 1
	fi

	echo "${LINE}" | sed -e "s/${SEARCH_STRING}//" -e 's/"//g'
	return 0
}


#####
# Display a message of various types in appropriate colors.
# Used primarily in installation scripts.
function display_msg()
{
	local LOG_IT="false"
	local LOG_ONLY="false"
	if [[ $1 == "--log" ]]; then
		LOG_IT="true"
		shift
	elif [[ $1 == "--logonly" ]]; then
		LOG_IT="true"
		LOG_ONLY="true"
		shift
	fi

	local LOG_TYPE="${1}"
	local MESSAGE="${2}"
	local NL=""
	if [[ ${MESSAGE:0:2} == "\n" ]]; then
		# If the message starts with "\n" then add newline BEFORE the "*".
		NL="\n"
		MESSAGE="${MESSAGE:2}"
	fi
	local MESSAGE2="${3}"		# optional 2nd message that's not in color
	local MSG=""
	local LOGMSG=""				# same as ${MSG} but no escape chars
	local STARS
	if [[ ${LOG_TYPE} == "error" ]]; then
		LOGMSG="*** ERROR: "
		MSG="\n${RED}${LOGMSG}"
		STARS=true

	elif [[ ${LOG_TYPE} == "warning" ]]; then
		LOGMSG="*** WARNING: "
		MSG="\n${YELLOW}${LOGMSG}"
		STARS=true

	elif [[ ${LOG_TYPE} == "notice" ]]; then
		LOGMSG="*** NOTICE: "
		MSG="\n${YELLOW}${LOGMSG}"
		STARS=true

	elif [[ ${LOG_TYPE} == "progress" ]]; then
		LOGMSG="${NL}* ${MESSAGE}"
		MSG="${GREEN}${LOGMSG}${NC}"
		STARS=false

	elif [[ ${LOG_TYPE} == "info" ]]; then
		LOGMSG="${NL}* ${MESSAGE}"
		MSG="${YELLOW}${LOGMSG}${NC}"
		STARS=false

	elif [[ ${LOG_TYPE} == "debug" ]]; then
		# Indent so they align with text above
		LOGMSG="${NL}  DEBUG: ${MESSAGE}"
		#shellcheck disable=SC2154
		MSG="${cDEBUG}${LOGMSG}${NC}"
		STARS=false

	else
		LOGMSG=""
		MSG="${YELLOW}"
		STARS=false
	fi

	if [[ ${STARS} == "true" ]]; then
		MSG+="\n"
		MSG+="**********\n"
		MSG+="${MESSAGE}\n"
		MSG+="**********${NC}\n"

		LOGMSG+="\n"
		LOGMSG+="**********\n"
		LOGMSG+="${MESSAGE}\n"
		LOGMSG+="**********\n"
	fi

	[[ ${LOG_ONLY} == "false" ]] && echo -e "${MSG}${MESSAGE2}"

	# Log messages to a file if it was specified.
	# ${DISPLAY_MSG_LOG} <should> be set if ${LOG_IT} is true, but just in case, check.

	[[ ${LOG_IT} == "false" || -z ${DISPLAY_MSG_LOG} ]] && return

	# Strip out all color escape sequences before adding to log file.
	# The message may have an actual escape character or may have the
	# four characters "\033" which represent an escape character.

	# I don't know how to replace "\n" with an
	# actual newline in sed, and there HAS to be a better way to strip the
	# escape sequences.
	# I simply replace actual escape characters in the input with "033" then 
	# replace "033[" with "033X".
	# Feel free to improve...

	# Assume if GREEN isn't defined then no colors are defined.
	if [[ -n ${GREEN} ]]; then
		local ESC="$( echo -en '\033' )"

		# Ignore any initial "\" in the colors.
		# In case a variable isn't defined, set it to a string that won't be found.
		local G="${GREEN/\\/}"							; G="${G/033\[/033X}"
		local Y="${YELLOW/\\/}"		; Y="${Y:-abcxyz}"	; Y="${Y/033\[/033X}"
		local R="${RED/\\/}"		; R="${R:-abcxyz}"	; R="${R/033\[/033X}"
		local D="${cDEBUG/\\/}"		; D="${D:-abcxyz}"	; D="${D/033\[/033X}"
		local N="${NC/\\/}"			; N="${N:-abcxyz}"	; N="${N/033\[/033X}"

		# Outer "echo -e" handles "\n" (2 characters) in input.
		# No "-e" needed on inner "echo".
		echo -e "$( echo "${LOGMSG}${MESSAGE2}" |
			sed -e "s/${ESC}/033/g" -e "s/033\[/033X/g" \
				-e "s/${G}//g" \
				-e "s/${Y}//g" \
				-e "s/${R}//g" \
				-e "s/${D}//g" \
				-e "s/${N}//g" \
		)"
	else
		echo "${LOGMSG}${MESSAGE2}"
	fi >>  "${DISPLAY_MSG_LOG}"
}


# The various upload protocols need different variables defined.
# For the specified protocol, make sure the specified variable is defined.
function check_PROTOCOL()
{
	local P="${1}"	# Protocol
	local V="${2}"	# Variable
	local N="${3}"	# Name
	local VALUE="$( settings ".${V}" "${ALLSKY_ENV}" )"
	if [[ -z ${VALUE} ]]; then
		echo "${N} Protocol (${P}) set but not '${V}'."
		echo "Uploads will not work until this is fixed."
		return 1
	fi
	return 0
}
# Check variables are correct for a remote server.
# Return 0 for OK, 1 for warning, 2 for error.
function check_remote_server()
{
	check_for_env_file || return 1

	local TYPE="${1}"
	local TYPE_STRING
	if [[ ${TYPE} == "REMOTEWEBSITE" ]]; then
		TYPE_STRING="Remote Website"
	else
		TYPE_STRING="Remote Server"
	fi

	local USE="$( settings ".use${TYPE,,}" )"
	if [[ ${USE} != "true" ]]; then
		# Variables should be empty.
		x="$( grep -E -v "^#|^$" "${ALLSKY_ENV}" | grep "${TYPE}" | grep -E -v "${TYPE}.*=\"\"|${TYPE}.*=$" )"
		if [[ -n "${x}" ]]; then
			echo "${TYPE_STRING} is not being used but settings for it exist in '${ALLSKY_ENV}:"
			indent "${x}" | sed "s/${TYPE}.*=.*/${TYPE}/"
			return 1
		fi
		return 0
	fi

	local RET=0
	local PROTOCOL="$( settings ".${TYPE,,}protocol" )"
	case "${PROTOCOL}" in
		"")
			echo "${TYPE_STRING} is being used but has no Protocol."
			echo "Uploads to it will not work."
			return 2
			;;

		ftp | ftps | sftp)
			check_PROTOCOL "${PROTOCOL}" "${TYPE}_HOST" "${TYPE_STRING}" || RET=1
			check_PROTOCOL "${PROTOCOL}" "${TYPE}_USER" "${TYPE_STRING}" || RET=1
			check_PROTOCOL "${PROTOCOL}" "${TYPE}_PASSWORD" "${TYPE_STRING}" || RET=1
			if [[ ${PROTOCOL} == "ftp" ]]; then
				echo "${TYPE_STRING} Protocol set to insecure 'ftp'."
				echo "Try using 'ftps' or 'sftp' instead."
				RET=1
			fi
			;;

		scp)
			check_PROTOCOL "${PROTOCOL}" "${TYPE}_HOST" "${TYPE_STRING}" || RET=1
			check_PROTOCOL "${PROTOCOL}" "${TYPE}_USER" "${TYPE_STRING}" || RET=1
			if check_PROTOCOL "${PROTOCOL}" "${TYPE}_SSH_KEY_FILE" "${TYPE_STRING}" \
					&& [[ ! -e ${SSH_KEY_FILE} ]]; then
				echo "${TYPE_STRING} Protocol (${PROTOCOL}) set but '${TYPE}_SSH_KEY_FILE' (${SSH_KEY_FILE}) does not exist."
				echo "Uploads will not work."
				RET=1
			fi
			;;

		s3)
			if check_PROTOCOL "${PROTOCOL}" "${TYPE}_AWS_CLI_DIR" "${TYPE_STRING}" \
					&& [[ ! -e ${AWS_CLI_DIR} ]]; then
				echo "${TYPE_STRING} Protocol (${PROTOCOL}) set but '${TYPE}_AWS_CLI_DIR' (${AWS_CLI_DIR}) does not exist."
				echo "Uploads will not work."
				RET=1
			fi
			check_PROTOCOL "${PROTOCOL}" "${TYPE}_S3_BUCKET" "${TYPE_STRING}" || RET=1
			check_PROTOCOL "${PROTOCOL}" "${TYPE}_S3_ACL" "${TYPE_STRING}" || RET=1
			;;

		gcs)
			check_PROTOCOL "${PROTOCOL}" "${TYPE}_GCS_BUCKET" "${TYPE_STRING}" || RET=1
			check_PROTOCOL "${PROTOCOL}" "${TYPE}_GCS_ACL" "${TYPE_STRING}" || RET=1
			;;

		*)
			echo "${TYPE_STRING} Protocol (${PROTOCOL}) not blank or one of: ftp, ftps, sftp, scp, s3, gcs."
			echo "Uploads will not work until this is corrected."
			RET=1
			;;
	esac

	REMOTE_PORT="$( get_variable "${TYPE}_PORT" "${ALLSKY_ENV}" )"
	if [[ -n ${REMOTE_PORT} ]] && ! is_number "${REMOTE_PORT}" ; then
		echo "${TYPE}_PORT (${REMOTE_PORT}) must be a number."
		echo "Uploads will not work until this is corrected."
		RET=1
	fi

	return "${RET}"
}


####
# Update a json file.   -d  deletes the field
function update_json_file()		# [-d] field, new value, file, [type]
{
	local M FIELD NEW_VALUE FILE TYPE DOUBLE_QUOTE TEMP ACTION

	M="${ME:-${FUNCNAME[0]}}"

	if [[ ${1} == "-d" ]]; then
		DELETE="true"
		shift
	else
		DELETE="false"
	fi

	FIELD="${1}"
	if [[ ${FIELD:0:1} != "." ]]; then
		echo "${M}: Field names must begin with period '.' (Field='${FIELD}')" >&2
		return 1
	fi

	FILE="${3:-${SETTINGS_FILE}}"
	TEMP="/tmp/$$"

	if [[ ${DELETE} == "true" ]]; then
		NEW_VALUE="(delete)"	# only used in error message below.
		ACTION="del(${FIELD})"
	else
		NEW_VALUE="${2}"
		TYPE="${4:-string}"		# optional
		if [[ ${TYPE} == "string" ]]; then
			DOUBLE_QUOTE='"'
		else
			DOUBLE_QUOTE=""
		fi
		ACTION="${FIELD} = ${DOUBLE_QUOTE}${NEW_VALUE}${DOUBLE_QUOTE}"
	fi
	if jq --indent 4 "${ACTION}" "${FILE}" > "${TEMP}" ; then
		# Have to use "cp" instead of "mv" to keep any hard link.
		cp "${TEMP}" "${FILE}"
		RET=0
	else
		RET=1
	fi
	rm "${TEMP}"

	if [[ ${RET} -ne 0 ]]; then
		echo "${M}: Unable to update json value of '${FIELD}' to '${NEW_VALUE}' in '${FILE}'." >&2
	fi

	return "${RET}"
}

####
# Update a Website configuration file from old to current version.
function update_website_config_file()
{
	local FILE PRIOR_VERSION CURRENT_VERSION LOCAL_OR_REMOTE

	FILE="${1}"
	PRIOR_VERSION="${2}"
	CURRENT_VERSION="${3}"
	LOCAL_OR_REMOTE="${4}"

	# Current version: 2
	if [[ ${PRIOR_VERSION} -eq 1 ]]; then
		# Version 2 removed AllskyWebsiteVersion.
		update_json_file -d ".AllskyWebsiteVersion" "" "${FILE}"
	fi

	# Set to current version.
	update_json_file ".${WEBSITE_CONFIG_VERSION}" "${CURRENT_VERSION}" "${FILE}"

	if [[ ${LOCAL_OR_REMOTE} == "local" ]]; then
		# Since we're installing a new Allsky, update the Allsky version.
		# For remote Websites it'll be updated when the user updates the Website.
		update_json_file ".${WEBSITE_ALLSKY_VERSION}" "${ALLSKY_VERSION}" "${FILE}"
	fi
}

####
# Create the lighttpd configuration file.
function create_lighttpd_config_file()
{
	local TMP="/tmp/x"

	sudo rm -f "${TMP}"
	sed \
		-e "s;XX_ALLSKY_WEBUI_XX;${ALLSKY_WEBUI};g" \
		-e "s;XX_WEBSERVER_OWNER_XX;${WEBSERVER_OWNER};g" \
		-e "s;XX_WEBSERVER_GROUP_XX;${WEBSERVER_GROUP};g" \
		-e "s;XX_ALLSKY_HOME_XX;${ALLSKY_HOME};g" \
		-e "s;XX_ALLSKY_IMAGES_XX;${ALLSKY_IMAGES};g" \
		-e "s;XX_ALLSKY_CONFIG_XX;${ALLSKY_CONFIG};g" \
		-e "s;XX_ALLSKY_WEBSITE_XX;${ALLSKY_WEBSITE};g" \
		-e "s;XX_ALLSKY_DOCUMENTATION_XX;${ALLSKY_DOCUMENTATION};g" \
		-e "s;XX_ALLSKY_OVERLAY_XX;${ALLSKY_OVERLAY};g" \
		-e "s;XX_MY_OVERLAY_TEMPLATES_XX;${MY_OVERLAY_TEMPLATES};g" \
			"${REPO_LIGHTTPD_FILE}"  >  "${TMP}"
	sudo install -m 0644 "${TMP}" "${LIGHTTPD_CONFIG_FILE}" && rm -f "${TMP}"
}

####
# Create the lighttpd log file with permissions so user can update it.
create_lighttpd_log_file()
{
	display_msg --log progress "Creating new ${LIGHTTPD_LOG_FILE}."

	# Remove any old log files.
	# Start off with a 0-length log file the user can write to.
	sudo -s -- <<-EOF
		chmod 755 "${LIGHTTPD_LOG_DIR}"
		rm -fr "${LIGHTTPD_LOG_DIR}"/*

		touch "${LIGHTTPD_LOG_FILE}"
		sudo chmod 664 "${LIGHTTPD_LOG_FILE}"
		sudo chown "${WEBSERVER_GROUP}:${ALLSKY_GROUP}" "${LIGHTTPD_LOG_FILE}"
	EOF
}

####
# Check for size of RAM+swap during installation (Issue # 969)
# and ask the user to increase if not "big enough".
# recheck_swap() is is referenced in the Allsky Documentation and can
# optionally be called after installation to adjust swap space.
recheck_swap()
{
	check_swap "prompt" "after_install"
}
check_swap()
{
	# global: TITLE  WT_WIDTH  SWAP_CONFIG_FILE
	local PROMPT  FROM_INSTALL
	PROMPT="false"; [[ ${1} == "prompt" ]] && PROMPT="true" && shift
	FROM_INSTALL="false"; [[ ${1} == "install" ]] && FROM_INSTALL="true" && shift

	if [[ ${FROM_INSTALL} == "true" ]]; then
		declare -n v="${FUNCNAME[0]}"; [[ ${v} == "true" && ${PROMPT} == "false" ]] && return
	fi

	local RAM_SIZE  DESIRED_COMBINATION  SUGGESTED_SWAP_SIZE  CURRENT_SWAP
	local f AMT  M  MSG  SWAP_SIZE  CURRENT_MAX

	# This can return "total_mem is unknown" if the OS is REALLY old.
	RAM_SIZE="$( vcgencmd get_config total_mem )"
	if [[ ${RAM_SIZE} =~ "unknown" ]]; then
		# Note: This doesn't produce exact results.  On a 4 GB Pi, it returns 3.74805.
		RAM_SIZE=$( free --mebi | awk '{if ($1 == "Mem:") {print $2; exit 0} }' )		# in MB
	else
		RAM_SIZE="${RAM_SIZE//total_mem=/}"
	fi
	DESIRED_COMBINATION=$((1024 * 5))		# desired minimum memory + swap
	SUGGESTED_SWAP_SIZE=0
	for i in 512 1024 2048 4096		# 8192 and above don't need any swap
	do
		if [[ ${RAM_SIZE} -le ${i} ]]; then
			SUGGESTED_SWAP_SIZE=$((DESIRED_COMBINATION - i))
			break
		fi
	done
	display_msg --logonly info "RAM_SIZE=${RAM_SIZE}, SUGGESTED_SWAP_SIZE=${SUGGESTED_SWAP_SIZE}."

	# Not sure why, but displayed swap is often 1 MB less than what's in /etc/dphys-swapfile
	CURRENT_SWAP=$( free --mebi | awk '{if ($1 == "Swap:") {print $2 + 1; exit 0} }' )	# in MB
	CURRENT_SWAP=${CURRENT_SWAP:-0}
	if [[ ${CURRENT_SWAP} -lt ${SUGGESTED_SWAP_SIZE} || ${PROMPT} == "true" ]]; then

		[[ -z ${FUNCTION} ]] && sleep 2		# give user time to read prior messages
		if [[ ${CURRENT_SWAP} -eq 1 ]]; then
			CURRENT_SWAP=0
			AMT="no"
			M="added"
		else
			AMT="${CURRENT_SWAP} MB of"
			M="increased"
		fi
		MSG="\nYour Pi currently has ${AMT} swap space."
		MSG+="\nBased on your memory size of ${RAM_SIZE} MB,"
		if [[ ${CURRENT_SWAP} -ge ${SUGGESTED_SWAP_SIZE} ]]; then
			SUGGESTED_SWAP_SIZE=${CURRENT_SWAP}
			MSG+=" there is no need to change anything, but you can if you would like."
		else
			MSG+=" we suggest ${SUGGESTED_SWAP_SIZE} MB of swap"
			MSG+=" to decrease the chance of timelapse and other failures."
			MSG+="\n\nDo you want swap space ${M}?"
			MSG+="\n\nYou may change the amount of swap space by changing the number below."
		fi

		SWAP_SIZE=$( whiptail --title "${TITLE}" --inputbox "${MSG}" 18 "${WT_WIDTH}" \
			"${SUGGESTED_SWAP_SIZE}" 3>&1 1>&2 2>&3 )
		# If the suggested swap was 0 and the user added a number but didn't first delete the 0,
		# do it now so we don't have numbers like "0256".
		[[ ${SWAP_SIZE:0:1} == "0" ]] && SWAP_SIZE="${SWAP_SIZE:1}"

		if [[ -z ${SWAP_SIZE} || ${SWAP_SIZE} == "0" ]]; then
			if [[ ${CURRENT_SWAP} -eq 0 && ${SUGGESTED_SWAP_SIZE} -gt 0 ]]; then
				display_msg --log warning "With no swap space you run the risk of programs failing."
			else
				display_msg --log info "Swap will remain at ${CURRENT_SWAP}."
			fi
		else
			display_msg --log progress "Setting swap space to ${SWAP_SIZE} MB."
			sudo dphys-swapfile swapoff					# Stops the swap file
			sudo sed -i "/CONF_SWAPSIZE/ c CONF_SWAPSIZE=${SWAP_SIZE}" "${SWAP_CONFIG_FILE}"

			CURRENT_MAX="$( get_variable "CONF_MAXSWAP" "${SWAP_CONFIG_FILE}" )"
			# TODO: Can we determine the default max rather than hard-code it?
			CURRENT_MAX="${CURRENT_MAX:-2048}"
			if [[ ${CURRENT_MAX} -lt ${SWAP_SIZE} ]]; then
				if [[ ${DEBUG} -gt 0 ]]; then
					display_msg --log debug "Increasing max swap size to ${SWAP_SIZE} MB."
				fi
				sudo sed -i "/CONF_MAXSWAP/ c CONF_MAXSWAP=${SWAP_SIZE}" "${SWAP_CONFIG_FILE}"
			fi

			sudo dphys-swapfile setup  > /dev/null		# Sets up new swap file
			sudo dphys-swapfile swapon					# Turns on new swap file
		fi
	else
		MSG="Size of current swap (${CURRENT_SWAP} MB) is sufficient; no change needed."
		display_msg --log progress "${MSG}"
	fi

	if [[ ${FROM_INSTALL} == "true" ]]; then
		STATUS_VARIABLES+=("${FUNCNAME[0]}='true'\n")
	fi
}
