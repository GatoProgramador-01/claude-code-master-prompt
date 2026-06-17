# Dev Machine Bootstrap — Claude Master Prompt

## How to use

Copy everything from **PROMPT START** to **PROMPT END** and paste it as your
first message in a new Claude Code session on the fresh machine.  
Claude will detect your OS and execute every step automatically.

> **Before you start** — you will need:
> - AWS Access Key ID + Secret Access Key (IAM user) **or** your SSO start URL
> - Your GitHub account credentials (browser login or a Personal Access Token)
> - Admin/sudo rights on the machine

---

## PROMPT START

You are bootstrapping a developer machine from scratch.
Follow every step below in order. Never skip a step.
If a command fails, diagnose the root cause and fix it before continuing.

---

### STEP 1 — Detect operating system

Run the appropriate detection command and store the result so every later
step can branch correctly.

**On Windows (PowerShell):**
```powershell
$env:OS
[System.Environment]::OSVersion.VersionString
winget --version
```

**On macOS / Linux (bash/zsh):**
```bash
uname -s          # Darwin | Linux
uname -m          # x86_64 | arm64
cat /etc/os-release 2>/dev/null | grep -E "^(ID|VERSION_ID)="
```

Based on the output, identify which OS branch to follow:
- `Windows_NT` → **Windows** branch
- `Darwin` → **macOS** branch
- `Linux` + `ID=ubuntu` or `ID=debian` → **Ubuntu/Debian** branch
- `Linux` + `ID=fedora`, `ID=rhel`, or `ID=amzn` → **Fedora/RHEL** branch
- `Linux` + `ID=arch` → **Arch** branch

---

### STEP 2 — Set up package manager

#### Windows
Verify winget is available (requires Windows 10 1709+ or Windows 11):
```powershell
winget --version
```
If winget is missing, open the Microsoft Store and install
**App Installer** (package `Microsoft.DesktopAppInstaller`), then re-run.

#### macOS
Check for Homebrew; install it if absent:
```bash
which brew || /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
After install on Apple Silicon, add brew to PATH:
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

#### Ubuntu / Debian
```bash
sudo apt update && sudo apt upgrade -y
```

#### Fedora / RHEL / Amazon Linux 2023
```bash
sudo dnf check-update && sudo dnf upgrade -y
```

#### Arch
```bash
sudo pacman -Syu --noconfirm
```

---

### STEP 3 — Install Git

#### Windows
```powershell
winget install --id Git.Git --exact --source winget
# Reload PATH in the current session
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")
git --version
```

#### macOS
```bash
brew install git
git --version
```

#### Ubuntu / Debian
```bash
sudo apt install git -y
git --version
```

#### Fedora / RHEL / Amazon Linux
```bash
sudo dnf install git -y
git --version
```

#### Arch
```bash
sudo pacman -S git --noconfirm
git --version
```

Set global identity (ask the user for their name and email, then run):
```bash
git config --global user.name  "FULL_NAME"
git config --global user.email "EMAIL"
git config --global init.defaultBranch main
```

---

### STEP 4 — Install GitHub CLI (gh)

#### Windows
```powershell
winget install --id GitHub.cli --exact --source winget
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")
gh --version
```

#### macOS
```bash
brew install gh
gh --version
```

#### Ubuntu / Debian
Add the official GitHub apt repository (do NOT use the distro package — it is outdated):
```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] \
  https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh -y
gh --version
```

#### Fedora / RHEL / Amazon Linux
```bash
sudo dnf install 'dnf-command(config-manager)' -y
sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
sudo dnf install gh -y
gh --version
```

#### Arch
```bash
sudo pacman -S github-cli --noconfirm
gh --version
```

**Authenticate gh** (runs interactively — the user will be prompted in the terminal):
```bash
gh auth login
```
When prompted:
1. Choose **GitHub.com**
2. Choose **HTTPS** as the protocol
3. Choose **Login with a web browser** (or paste a Personal Access Token)
4. Follow the browser prompt or paste the one-time code

Verify:
```bash
gh auth status
```

---

### STEP 5 — Install AWS CLI v2

#### Windows
```powershell
winget install --id Amazon.AWSCLI --exact --source winget
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")
aws --version
```
If winget does not find it, download the MSI installer directly:
```powershell
Invoke-WebRequest -Uri "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "$env:TEMP\AWSCLIV2.msi"
Start-Process msiexec.exe -Wait -ArgumentList "/i $env:TEMP\AWSCLIV2.msi /quiet"
aws --version
```

#### macOS
```bash
brew install awscli
aws --version
```

#### Ubuntu / Debian (x86_64)
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
aws --version
```
For ARM64:
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o /tmp/awscliv2.zip
unzip /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
aws --version
```

#### Fedora / RHEL / Amazon Linux
```bash
# Amazon Linux 2023 ships aws-cli v2 in the default repos:
sudo dnf install awscli2 -y
# On Fedora / RHEL use the same zip installer as Ubuntu (see above)
aws --version
```

#### Arch
```bash
sudo pacman -S aws-cli-v2 --noconfirm
aws --version
```

---

### STEP 6 — Configure AWS credentials

Ask the user which credential mode to use:

> "Which AWS setup do you need?
>  A) IAM user — Access Key + Secret (local dev / personal account)
>  B) AWS SSO / Identity Center (company/federated login)
>  C) Named profiles — multiple accounts (e.g. dev + prod)
>  Type A, B, or C."

---

#### Option A — IAM user (local dev)

Tell the user to have their **Access Key ID** and **Secret Access Key** ready
from the AWS IAM console, then run the interactive configurator:
```bash
aws configure
```
It will prompt for:
- `AWS Access Key ID` — paste from IAM console
- `AWS Secret Access Key` — paste from IAM console
- `Default region name` — e.g. `us-east-1`
- `Default output format` — `json`

> **Security note:** `~/.aws/credentials` is a system file and is NOT committed
> to git. It is safe for local dev. Never put credentials in `.env` files,
> source code, or Terraform `.tfvars` files committed to a repo.

Verify:
```bash
aws sts get-caller-identity
```
Expected output: your AWS account ID, user ARN, and user ID.

---

#### Option B — AWS SSO / Identity Center

Ask the user for:
- Their SSO **start URL** (e.g. `https://mycompany.awsapps.com/start`)
- Their SSO **region** (e.g. `us-east-1`)

Then run:
```bash
aws configure sso
```
It will prompt for:
- `SSO session name` — any label, e.g. `mycompany`
- `SSO start URL` — paste the URL above
- `SSO region` — the SSO region
- `SSO registration scopes` — accept default (`sso:account:access`)

A browser will open for login. After authentication, select the account and role.

Set the profile as default for the session:
```bash
export AWS_PROFILE=<profile-name-shown-by-configure-sso>   # macOS/Linux
$env:AWS_PROFILE = "<profile-name>"                         # Windows PowerShell
```

Or add it permanently to shell config:
```bash
echo 'export AWS_PROFILE=<profile-name>' >> ~/.zshrc   # macOS zsh
echo 'export AWS_PROFILE=<profile-name>' >> ~/.bashrc  # Linux bash
```

Verify:
```bash
aws sso login --profile <profile-name>
aws sts get-caller-identity --profile <profile-name>
```

---

#### Option C — Named profiles (multiple accounts)

Run `aws configure` once per profile:
```bash
aws configure --profile dev
aws configure --profile prod
```
Each profile stores its own credentials and region in `~/.aws/credentials`
and `~/.aws/config`.

Set the active profile for the shell session:
```bash
export AWS_PROFILE=dev       # macOS/Linux
$env:AWS_PROFILE = "dev"     # Windows PowerShell
```

> **CI/CD note:** For GitHub Actions and any non-interactive environment,
> do NOT create static IAM keys. Use OIDC trust between the GitHub Actions
> runner and an IAM Role instead — that is what the `infra/bootstrap/` in
> this repo provisions. Static keys in CI are a security anti-pattern.

Verify:
```bash
aws sts get-caller-identity
```

---

### STEP 7 — Verify full setup

Run all checks and report status for each:

```bash
git --version        # should print git version
gh auth status       # should show "Logged in to github.com"
aws --version        # should print aws-cli/2.x.x
aws sts get-caller-identity  # should return your account JSON
```

On Windows (PowerShell):
```powershell
git --version
gh auth status
aws --version
aws sts get-caller-identity
```

If any check fails, fix it before proceeding.

---

### STEP 8 — (Optional) Clone the private repo

Ask the user:
> "Do you want to clone a private GitHub repo now? If yes, paste the repo
> URL or owner/repo (e.g. JavierCollipal/multiagent-aws-infra)."

If the user provides a repo, clone it:
```bash
gh repo clone <owner/repo>
cd <repo>
```

Then verify the repo is healthy (adjust to the project's test command):
```bash
# Python project
python -m pytest services/ -v --tb=short

# Node project
npm install && npm test
```

---

### Final summary

Report a checklist to the user:

```
[ ] Git installed and configured (name, email, default branch)
[ ] GitHub CLI installed and authenticated
[ ] AWS CLI v2 installed
[ ] AWS credentials configured (profile: _______)
[ ] aws sts get-caller-identity returns correct account
[ ] (optional) Repo cloned and tests passing
```

If everything is checked, the machine is ready.

## PROMPT END
