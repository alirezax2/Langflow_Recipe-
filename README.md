# Install Langflow in an Incus Container on Ubuntu in WSL2

A practical, end-to-end recipe for running Langflow in an Incus container inside Ubuntu on Windows Subsystem for Linux (WSL2), then opening Langflow from a Windows browser.

> **Example names used in this guide**
>
> - Windows username: `alireza`
> - WSL distribution: `Ubuntu-24.04`
> - Incus container: `mylangflow`
> - Langflow port: `7860`
> - Langflow container IP: `10.2.44.21` (your IP may differ)
>
> Replace example names and addresses with your own. Run commands in the terminal specified in each section.

## 1. What are WSL, Ubuntu, and Incus?

### Windows Subsystem for Linux (WSL)

**WSL** is a Microsoft feature that lets you run a Linux environment directly on Windows without managing a traditional virtual machine yourself. WSL2 uses a lightweight virtual machine and a real Linux kernel.

You can use Linux command-line tools, install Linux packages, run services, and administer containers while continuing to use Windows applications.

### Ubuntu

**Ubuntu** is a Linux distribution. Installing Ubuntu in WSL gives you a Linux shell and filesystem in which to install tools such as Incus, Python, and `uv`.

### Incus

**Incus** is a system container and virtual-machine manager. It can run isolated Linux containers with their own filesystem, network interface, and services.

### Langflow

**Langflow** is a visual platform for building AI workflows and agent flows. In this setup, Langflow runs as a Python application inside an Ubuntu Incus container.

### How the pieces fit together

```text
Windows
├── Chrome / Edge
│   └── http://localhost:7860
└── WSL2
    └── Ubuntu
        └── Incus
            └── Container: mylangflow
                └── systemd service: Langflow
                    └── Port 7860
```

Windows must be able to reach the WSL service, and the Incus host must be able to reach the Langflow container. The Incus proxy device in this guide forwards a port on the WSL host to the container.

---

## 2. Install WSL and Ubuntu on Windows

Open **Windows PowerShell as Administrator**.

### 2.1 Install WSL with Ubuntu 24.04

```powershell
wsl --install -d Ubuntu-24.04
```

If Windows asks you to restart, restart the computer.

> If `Ubuntu-24.04` is not available on your Windows installation, list available distributions with `wsl --list --online` and choose an available Ubuntu distribution.

### 2.2 Complete Ubuntu first-run setup

Open Ubuntu from the Start menu. On first launch, Ubuntu asks you to create a Linux username and password. This is a Linux account, separate from your Windows account.

### 2.3 Verify that Ubuntu uses WSL2

In PowerShell:

```powershell
wsl --list --verbose
```

The `VERSION` column should show `2` for your Ubuntu distribution.

If it shows `1`, convert the distribution:

```powershell
wsl --set-version Ubuntu-24.04 2
```

You can set WSL2 as the default for future distributions:

```powershell
wsl --set-default-version 2
```

### 2.4 Update Ubuntu

In the Ubuntu terminal:

```bash
sudo apt update
sudo apt upgrade -y
```

---

## 3. Enable systemd in WSL

Incus uses system services. Recent WSL versions support `systemd`.

In Ubuntu, edit `/etc/wsl.conf`:

```bash
sudo vi /etc/wsl.conf
```

Add the following section if it is not already present. Do not create a second `[boot]` section if one already exists.

```ini
[boot]
systemd=true
```

Save and exit `vi` by pressing `Esc`, typing `:wq`, and pressing Enter.

From **Windows PowerShell**, fully stop WSL:

```powershell
wsl --shutdown
```

Start Ubuntu again, then verify systemd:

```bash
systemctl is-system-running
```

It may report `running` or, depending on services in the distribution, `degraded`. If systemd is not PID 1, check your WSL version and `/etc/wsl.conf`.

---

## 4. Install and initialize Incus in Ubuntu

> Skip to Section 5 if Incus is already installed and `sudo incus list` works.

In the Ubuntu/WSL terminal:

```bash
sudo apt update
sudo apt install -y incus
```

If your Ubuntu package sources do not contain Incus, make sure the `universe` repository is enabled and run `sudo apt update` again. Follow the official Incus installation instructions for your Ubuntu release if the package is still unavailable.

Check the installation:

```bash
incus version
systemctl status incus
```

If the daemon is installed but not running, try:

```bash
sudo systemctl enable --now incus
```

Initialize Incus if this is a new installation:

```bash
sudo incus admin init
```

Follow the prompts. For a basic local setup, the default answers are generally appropriate. Avoid initializing an existing Incus installation again unless you know you need to change its configuration.

Check that Incus responds:

```bash
sudo incus list
```

### Optional: use Incus without `sudo`

First check whether the group exists:

```bash
getent group incus
```

If it exists, add your Linux user to it:

```bash
sudo usermod -aG incus "$USER"
```

Log out of the Linux session and back in, or restart the WSL distribution, then verify with `groups` and `incus list`.

**Security:** Incus administrative access can provide extensive control over containers and may allow host-level access. Only grant it to trusted users. Using `sudo incus ...` is fine if you prefer not to change group membership.

---

## 5. Create the Langflow container

If you already have a running container named `mylangflow`, do not create another one. Go to Section 6.

On the Ubuntu/WSL host:

```bash
sudo incus launch images:ubuntu/24.04 mylangflow \
  -c limits.cpu=4 \
  -c limits.memory=6GiB
```

Check its status and IP address:

```bash
sudo incus list
sudo incus exec mylangflow -- hostname -I
```

Record the container's IPv4 address. In the example setup it is `10.2.44.21`, but Incus may assign a different address on your machine.

### Optional: mount a persistent data directory

Langflow stores project and application data in its configured data directory. Keep important data on persistent storage and back it up before upgrades or changes.

For a new container, you can create a host directory and mount it into the container:

```bash
sudo mkdir -p /var/lib/amirlangflow
sudo incus config device add mylangflow langflow-data disk \
  source=/var/lib/amirlangflow path=/var/lib/langflow
```

**Important:** A mount at `/var/lib/langflow` does not automatically relocate every Langflow database or file. Confirm Langflow's actual data-directory configuration before relying on this mount for persistence. If you are adding this to an existing installation, back up its data first.

---

## 6. Install Langflow inside the container

Enter the container from the Ubuntu/WSL host:

```bash
sudo incus exec mylangflow -- bash
```

The following commands run **inside the container**.

### 6.1 Install system dependencies

```bash
apt update
apt install -y curl git build-essential \
  python3 python3-venv python3-dev \
  libffi-dev libssl-dev
```

### 6.2 Install `uv`

`uv` is a Python package and environment manager.

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
install -m 755 /root/.local/bin/uv /usr/local/bin/uv
```

Check it:

```bash
uv --version
```

### 6.3 Create a Python environment and install Langflow

```bash
mkdir -p /opt/langflow
cd /opt/langflow

uv venv --python 3.12 .venv
uv pip install --python .venv/bin/python langflow
```

Check the installed command:

```bash
/opt/langflow/.venv/bin/langflow --version
```

If the installation fails due to a Python version or dependency requirement, check the current Langflow installation documentation and use a supported Python version.

---

## 7. Configure Langflow environment variables

Still inside the container, create the environment file:

```bash
vi /etc/langflow.env
```

Add:

```dotenv
LANGFLOW_AUTO_LOGIN=false
LANGFLOW_SUPERUSER=langflow
LANGFLOW_SUPERUSER_PASSWORD=REPLACE_WITH_A_LONG_UNIQUE_PASSWORD
LANGFLOW_CUSTOM_COMPONENT_ADMIN_ONLY=true
DO_NOT_TRACK=true
```

Replace the password with a strong, unique password. Do not commit this file or its password to Git.

Protect the file:

```bash
chmod 600 /etc/langflow.env
```

### Security notes

- Keep Langflow behind a trusted network or reverse proxy with HTTPS if you need remote access.
- Custom components can execute Python code on the server. `LANGFLOW_CUSTOM_COMPONENT_ADMIN_ONLY=true` restricts custom-component authoring to administrators.
- If you do not need custom components, consider disabling them using the setting supported by your installed Langflow version.
- Do not expose port 7860 directly to the public internet.

---

## 8. Run Langflow with systemd

Create the service file:

```bash
vi /etc/systemd/system/langflow.service
```

Paste:

```ini
[Unit]
Description=Langflow AI workflow platform
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/langflow
EnvironmentFile=/etc/langflow.env
ExecStart=/opt/langflow/.venv/bin/langflow run --host 0.0.0.0 --port 7860
Restart=on-failure
RestartSec=5
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
```

Save the file, then enable and start the service:

```bash
systemctl daemon-reload
systemctl enable --now langflow
systemctl status langflow
```

Check the logs:

```bash
journalctl -u langflow -n 100 --no-pager
```

Test Langflow from inside the container:

```bash
curl -I http://127.0.0.1:7860/
```

A response such as `HTTP/1.1 200 OK` confirms that the HTTP endpoint is responding. It does not by itself prove that Windows networking is configured.

---

## 9. Forward the Incus container port to the WSL host

Windows cannot necessarily reach an Incus container's private IP directly. Create an Incus proxy device to forward port 7860 from the WSL/Ubuntu host to the container.

First, exit the container:

```bash
exit
```

You should now be back in the Ubuntu/WSL terminal.

Get the container IP:

```bash
sudo incus list
```

Assume the container IP is `10.2.44.21`. Create a proxy device:

```bash
sudo incus config device add mylangflow langflow-ui proxy \
  listen=tcp:127.0.0.1:7860 \
  connect=tcp:10.2.44.21:7860
```

This binds the proxy to the WSL host's loopback interface, rather than all WSL network interfaces. Test it in WSL:

```bash
curl -I http://127.0.0.1:7860/
```

If the device already exists, inspect it first:

```bash
sudo incus config device show mylangflow
```

If you need to recreate only this device:

```bash
sudo incus config device remove mylangflow langflow-ui
```

Then run the `incus config device add` command again.

### If WSL localhost forwarding does not work

WSL2 usually forwards Linux localhost services to Windows `localhost`, but behavior can depend on WSL networking mode and configuration.

If Windows cannot connect to `localhost:7860`, try binding the Incus proxy to all WSL IPv4 interfaces:

```bash
sudo incus config device remove mylangflow langflow-ui

sudo incus config device add mylangflow langflow-ui proxy \
  listen=tcp:0.0.0.0:7860 \
  connect=tcp:10.2.44.21:7860
```

**Security warning:** `0.0.0.0` listens on all WSL IPv4 interfaces. Use it only if needed, and ensure Windows Firewall and your network setup do not expose the service to untrusted networks. Prefer loopback binding when it works.

---

## 10. Open Langflow from Windows

Open Chrome or Edge on Windows and navigate to:

**http://localhost:7860**

Sign in with the account configured for Langflow, if prompted.

### Test the port from Windows PowerShell

If the page does not load, open PowerShell (not the Ubuntu terminal) and run:

```powershell
Test-NetConnection localhost -Port 7860
```

Look for:

```text
TcpTestSucceeded : True
```

If it is `False`, continue with the troubleshooting section.

### Alternative: access through the WSL IP

Find the WSL host's IPv4 addresses in Ubuntu:

```bash
hostname -I
```

You may see several addresses, for example `172.19.234.215`, `10.213.216.1`, and `10.2.44.1`. These are different interfaces; do not assume they are interchangeable.

If the Incus proxy listens only on `127.0.0.1`, the WSL IP will not accept connections on port 7860. If you deliberately configure the proxy to listen on `0.0.0.0`, you can test a suitable WSL IP from Windows:

```text
http://WSL_IP:7860
```

Use `http://localhost:7860` first.

---

## 11. Troubleshooting

Run each command in the environment indicated.

### Check the container and IP (Ubuntu/WSL host)

```bash
sudo incus list
sudo incus exec mylangflow -- hostname -I
```

### Check Langflow's systemd service (inside container)

```bash
systemctl status langflow
journalctl -u langflow -n 100 --no-pager
```

Or run these from the WSL host without entering the container:

```bash
sudo incus exec mylangflow -- systemctl status langflow
sudo incus exec mylangflow -- journalctl -u langflow -n 100 --no-pager
```

### Test the application inside the container

```bash
sudo incus exec mylangflow -- \
  curl -I http://127.0.0.1:7860/
```

### Check the Incus proxy configuration

```bash
sudo incus config device show mylangflow
```

### Test the forwarded port on the WSL host

```bash
curl -I http://127.0.0.1:7860/
```

### Test from Windows PowerShell

```powershell
Test-NetConnection localhost -Port 7860
```

### Interpret the results

| Test | Result | Likely next step |
|---|---|---|
| Container-local `curl` | Fails | Check Langflow service and logs |
| Container-local `curl` | Works | Langflow is responding inside the container |
| WSL-host `curl` | Fails | Check the Incus proxy device and container IP |
| WSL-host `curl` | Works, Windows test fails | Check WSL localhost forwarding and proxy listen address |
| Windows test succeeds, browser fails | Port is reachable | Check browser URL, HTTP/HTTPS, and application response |

---

## 12. Useful everyday commands

Run these on the Ubuntu/WSL host:

| Task | Command |
|---|---|
| List containers | `sudo incus list` |
| Enter Langflow container | `sudo incus exec mylangflow -- bash` |
| Container IP | `sudo incus exec mylangflow -- hostname -I` |
| Restart Langflow | `sudo incus exec mylangflow -- systemctl restart langflow` |
| Check status | `sudo incus exec mylangflow -- systemctl status langflow` |
| Follow logs | `sudo incus exec mylangflow -- journalctl -u langflow -f` |
| Stop container | `sudo incus stop mylangflow` |
| Start container | `sudo incus start mylangflow` |

To stop WSL from Windows PowerShell:

```powershell
wsl --shutdown
```

Start Ubuntu again from the Start menu or with:

```powershell
wsl -d Ubuntu-24.04
```

Once WSL and Incus are running again, check the container and Langflow service if the browser cannot connect.

---

## 13. Official documentation

- [Install WSL](https://learn.microsoft.com/windows/wsl/install)
- [WSL configuration](https://learn.microsoft.com/windows/wsl/wsl-config)
- [Incus documentation](https://linuxcontainers.org/incus/docs/main/)
- [Langflow installation documentation](https://docs.langflow.org/getting-started-installation/)

## Final checklist

- [ ] WSL2 and Ubuntu are installed.
- [ ] systemd works in Ubuntu on WSL.
- [ ] Incus is initialized and `sudo incus list` works.
- [ ] The `mylangflow` container is running.
- [ ] Langflow is installed in `/opt/langflow/.venv`.
- [ ] The `langflow` systemd service is enabled and running.
- [ ] Container-local `curl` returns an HTTP response.
- [ ] The Incus proxy forwards port `7860` to the current container IP.
- [ ] Windows PowerShell reports `TcpTestSucceeded : True`.
- [ ] Langflow opens at `http://localhost:7860`.
- [ ] Credentials are strong and port 7860 is not unintentionally exposed to untrusted networks.

## 14. Host Langflow on Coolify

For Coolify, you can run Langflow directly in a Docker container using the official Langflow image, with port `7860` exposed. This setup does not require Incus or WSL on the Coolify server.

The following production-oriented configuration uses environment-based settings, persistent storage for Langflow data, and a health check.

### Dockerfile

Add this `Dockerfile` to the root of your Git repository. It uses the official Langflow image and configures `/app/langflow` as the application data directory to persist in Coolify.

```dockerfile
# Official Langflow image; pin the version for reproducible deployments
FROM langflowai/langflow:1.13.0

# Langflow configuration
ENV LANGFLOW_HOST=0.0.0.0 \
    LANGFLOW_PORT=7860 \
    LANGFLOW_AUTO_LOGIN=false \
    LANGFLOW_CONFIG_DIR=/app/langflow \
    LANGFLOW_SAVE_DB_IN_CONFIG_DIR=true \
    LANGFLOW_CUSTOM_COMPONENT_ADMIN_ONLY=true \
    LANGFLOW_LOG_ENV=container

# Persistent application data directory
WORKDIR /app
RUN mkdir -p /app/langflow

# Langflow web UI and API
EXPOSE 7860

# Start Langflow
CMD ["langflow", "run", "--host", "0.0.0.0", "--port", "7860"]
```

### Configure Coolify

1. **Push to Git.** Commit and push the `Dockerfile` to a Git repository connected to Coolify.
2. **Create an application.** Create a new application from your repository. Select **Dockerfile** as the build pack and set the Dockerfile path to `Dockerfile`.
3. **Set environment variables.** Add the following in the application's environment-variable settings. Use a strong, unique password and do not commit secrets to Git.

   ```dotenv
   LANGFLOW_SUPERUSER=langflow
   LANGFLOW_SUPERUSER_PASSWORD=REPLACE_WITH_A_STRONG_UNIQUE_PASSWORD
   ```

4. **Add persistent storage.** Configure a persistent volume or storage mount at `/app/langflow`. This keeps Langflow's database, configuration, and uploaded files outside the disposable container filesystem.
5. **Deploy.** Set the container port to `7860`. If configuring a health check, use `/health`. Enable HTTPS through Coolify's domain configuration.

### Recommended settings

| Setting | Value |
|---|---|
| Build method | Dockerfile |
| Dockerfile location | `/Dockerfile` or `Dockerfile`, depending on the Coolify field |
| Internal port | `7860` |
| Persistent mount | `/app/langflow` |
| Authentication | Enabled |
| Automatic login | Disabled |
| Custom components | Admin-only |

The Dockerfile pins Langflow to version `1.13.0` so deployments do not unexpectedly change when a new image is released. Check the [official Langflow Docker deployment guide](https://docs.langflow.org/deployment-docker) before upgrading to another version.

This setup is suitable for a single-instance Langflow deployment. If you later scale to multiple replicas, use a shared, supported database such as PostgreSQL and review the requirements for shared storage and secrets.
