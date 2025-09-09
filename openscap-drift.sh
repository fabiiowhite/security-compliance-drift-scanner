#!/bin/bash

# ==============================
# OpenSCAP Drift Detection Script
# RHEL 10
# ==============================

CONFIG_FILE="/etc/openscap-drift.conf"
LOG_FILE="/var/log/openscap-drift.log"
BASELINE_FILE="/var/lib/openscap/baseline.xml"
RESULT_FILE="/var/lib/openscap/last_scan.xml"
REPORT_FILE="/var/lib/openscap/last_scan.html"

# Ensure root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root"
  exit 1
fi

# RHEL version fixed
RHEL_VERSION=10
SCAP_FILE="/usr/share/xml/scap/ssg/content/ssg-rhel${RHEL_VERSION}-ds.xml"

if [ ! -f "$SCAP_FILE" ]; then
  echo "❌ SCAP file not found for RHEL $RHEL_VERSION"
  echo "Please install scap-security-guide:"
  echo "  sudo yum install -y scap-security-guide"
  exit 1
fi

# First-time setup or reconfiguration
if [ ! -f "$CONFIG_FILE" ]; then
  OVERWRITE="y"
else
  echo "⚠️ Configuration file $CONFIG_FILE already exists."
  read -p "Do you want to overwrite it? (y/N): " OVERWRITE
fi

if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
  echo "==== 🛠️ OpenSCAP Drift Detection Setup ===="
  
  read -p "📧 Enter notification email: " USER_EMAIL

  # Extract available profiles
  PROFILES=($(oscap info "$SCAP_FILE" | grep -oP 'xccdf_org\.ssgproject\.content_profile_\S+'))
  
  if [ ${#PROFILES[@]} -eq 0 ]; then
    echo "❌ No profiles found in $SCAP_FILE"
    exit 1
  fi

  echo "🔹 Available baseline profiles for RHEL $RHEL_VERSION:"
  for i in "${!PROFILES[@]}"; do
      echo "$((i+1))) ${PROFILES[$i]}"
  done

  read -p "📋 Enter the number of the baseline profile to use: " PROFILE_NUM
  if ! [[ "$PROFILE_NUM" =~ ^[0-9]+$ ]] || [ "$PROFILE_NUM" -lt 1 ] || [ "$PROFILE_NUM" -gt "${#PROFILES[@]}" ]; then
      echo "❌ Invalid selection"
      exit 1
  fi
  BASELINE="${PROFILES[$((PROFILE_NUM-1))]}"
  echo "✅ Selected baseline: $BASELINE"

  # Save configuration
  echo "EMAIL=$USER_EMAIL" > $CONFIG_FILE
  echo "BASELINE=$BASELINE" >> $CONFIG_FILE
  echo "SCAP_FILE=$SCAP_FILE" >> $CONFIG_FILE
  echo "✅ Configuration saved at $CONFIG_FILE"
  
  # Run initial baseline scan
  mkdir -p /var/lib/openscap
  echo "🔎 Running initial baseline scan..."
  oscap xccdf eval --profile $BASELINE \
       --results $BASELINE_FILE \
       --report $REPORT_FILE \
       $SCAP_FILE
  echo "✅ Initial baseline scan complete."
  exit 0
elif [[ -f "$CONFIG_FILE" ]]; then
  echo "ℹ️ Using existing configuration."
fi

# Load config
source $CONFIG_FILE

# Ensure log file exists
mkdir -p $(dirname $LOG_FILE)
touch $LOG_FILE
chmod 644 $LOG_FILE

# Run scan
echo "🔄 Running drift scan..."
oscap xccdf eval --profile $BASELINE \
     --results $RESULT_FILE \
     --report $REPORT_FILE \
     $SCAP_FILE

# Extract failed rules for clean email
DIFF=$(oscap xccdf generate report $RESULT_FILE | \
       grep -i "fail" | awk -F':' '{print "Rule: "$1"\nStatus: "$2"\n"}')

# Prepare email body
HOSTNAME=$(hostname)
EMAIL_BODY="🔔 OpenSCAP Drift Alert on $HOSTNAME\n"
EMAIL_BODY+="Date: $(date)\n\n"

if [ -z "$DIFF" ]; then
    EMAIL_BODY+="✅ No compliance drift detected.\n"
    echo "$(date) - ✅ No Drift Detected" >> $LOG_FILE
else
    TOTAL_FAILS=$(echo "$DIFF" | grep -c "Rule:")
    EMAIL_BODY+="⚠️ Compliance drift detected:\n\n$DIFF\n"
    EMAIL_BODY+="Summary: $TOTAL_FAILS failed rules detected.\n"
    echo "$(date) - ⚠️ Drift Detected ($TOTAL_FAILS failed rules)" >> $LOG_FILE
    
    # Send email with custom sender display name
    if echo -e "$EMAIL_BODY" | mail -s "OpenSCAP Drift Report on $HOSTNAME" \
         -r "Compliance Drift Scanner <$HOSTNAME@$HOSTNAME>" $EMAIL; then
        echo "$(date) - ⚠️ Drift email sent to $EMAIL" >> $LOG_FILE
    else
        echo "$(date) - ⚠️ Drift detected but email sending FAILED" >> $LOG_FILE
    fi
fi
