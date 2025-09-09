# OpenSCAP Drift Detection Tool for RHEL 10 – Full Documentation

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Postfix Installation and Configuration](#postfix-installation-and-configuration)
5. [OpenSCAP Drift Detection Setup](#openscap-drift-detection-setup)
6. [Systemd Service & Timer Setup](#systemd-service--timer-setup)
7. [Cron/Timer Usage](#crontimer-usage)
8. [Configuration File](#configuration-file)
9. [Logs](#logs)
10. [Output Files](#output-files)

---

## 1️⃣ Overview

The **OpenSCAP Drift Detection Tool** is a Bash-based automation script for **RHEL 10** that:

* Performs compliance scans against a selected SCAP baseline.
* Detects configuration drift from the baseline.
* Sends email notifications when drift is detected.
* Generates a human-readable HTML report.
* Runs automatically as a **systemd service** via a **systemd timer**.

---

## 2️⃣ Prerequisites

* RHEL 10 system
* Root access
* Internet connectivity to install packages
* Required packages:

  * `openscap-scanner`
  * `scap-security-guide`
  * `mailx` (for sending emails)
  * `postfix` (SMTP server)

---

## 3️⃣ Installation

1. Copy the script to a suitable location and make it executable:

```bash
sudo cp openscap-drift.sh /usr/local/bin/openscap-drift.sh
sudo chmod +x /usr/local/bin/openscap-drift.sh
```

2. Ensure the SCAP content for RHEL 10 is installed:

```bash
sudo yum install -y scap-security-guide openscap-scanner
```

3. Ensure `mailx` is installed:

```bash
sudo yum install -y mailx
```

---

## 4️⃣ Postfix Installation and Configuration

1. Install Postfix:

```bash
sudo yum install -y postfix
```

2. Enable and start Postfix:

```bash
sudo systemctl enable --now postfix
```

3. Configure Postfix for sending local mail (minimal setup for drift alerts):

```bash
sudo postconf -e "myhostname = $(hostname)"
sudo postconf -e "mydomain = localdomain"
sudo postconf -e "myorigin = \$mydomain"
sudo postconf -e "inet_interfaces = loopback-only"
sudo postconf -e "inet_protocols = ipv4"
sudo systemctl restart postfix
```

4. Test email sending:

```bash
echo "Test email from OpenSCAP Drift Detection" | mail -s "Test Email" youremail@example.com
```

> ⚠️ For external email delivery, you may need to configure a relay host or SMTP credentials.

---

## 5️⃣ OpenSCAP Drift Detection Setup

Run the script as root:

```bash
sudo /usr/local/bin/openscap-drift.sh
```

During first-time setup:

1. Enter the **notification email address**.
2. Select the SCAP **baseline profile** to use.
3. The script runs an initial **baseline scan** stored in:

   * `/var/lib/openscap/baseline.xml` (results)
   * `/var/lib/openscap/last_scan.html` (HTML report)

The configuration will be saved at `/etc/openscap-drift.conf`.

---

## 6️⃣ Systemd Service & Timer Setup

### Service File

Create `/etc/systemd/system/openscap-drift.service`:

```ini
[Unit]
Description=OpenSCAP Drift Detection Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/openscap-drift.sh
User=root
Group=root
StandardOutput=journal
StandardError=journal
```

### Timer File

Create `/etc/systemd/system/openscap-drift.timer`:

```ini
[Unit]
Description=Run OpenSCAP Drift Detection daily

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

### Enable and Start Timer

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now openscap-drift.timer
systemctl list-timers | grep openscap-drift
```

This ensures the script runs **daily at 2 AM** automatically.

---

## 7️⃣ Cron/Timer Usage

After the service/timer is configured, you **do not need a cron job**. Systemd handles execution.

Check status:

```bash
systemctl status openscap-drift.timer
```

Check last run logs:

```bash
journalctl -u openscap-drift.service -b
```

---

## 8️⃣ Configuration File

Stored at `/etc/openscap-drift.conf`:

```bash
EMAIL=youremail@example.com
BASELINE=xccdf_org.ssgproject.content_profile_standard
SCAP_FILE=/usr/share/xml/scap/ssg/content/ssg-rhel10-ds.xml
```

* `EMAIL`: recipient for notifications
* `BASELINE`: selected SCAP profile
* `SCAP_FILE`: path to SCAP content

---

## 9️⃣ Logs

* File: `/var/log/openscap-drift.log`
* Contents:

  * Timestamped drift detection results
  * Email sending status
  * Summary of failed rules

Check logs:

```bash
tail -f /var/log/openscap-drift.log
```

---

## 10️⃣ Output Files

| File                               | Description                   |
| ---------------------------------- | ----------------------------- |
| `/var/lib/openscap/baseline.xml`   | Initial baseline scan results |
| `/var/lib/openscap/last_scan.xml`  | Latest scan results           |
| `/var/lib/openscap/last_scan.html` | Human-readable HTML report    |

---

ENJOYYYYYYYYY!
