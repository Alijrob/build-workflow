# Project Setup Prompt

Fill in the variables at the bottom, then paste this entire file into Claude Code
at the start of a new project.

---

PROJECT SETUP AND PHASE PLANNING PROMPT

You are helping me set up this project so it can be built in controlled, trackable
install/build phases.

Primary objective:
Break this project into clear, trackable install/build phases that can be completed
across multiple AI or developer sessions without losing context.

Global rule:
Adversarial verification applies to every repo, every phase, every install, every
commit, every push, and every final report unless explicitly overridden.

Critical behavior rule:
Claude Code must be verification-first, not confidence-first. Prove repo state,
file state, commit state, push state, and test state with commands before claiming
success. If something cannot be proven, label it unverified, inferred, or blocked.

Claude Code adaptation rules:
- Inspect the current folder before assuming the project structure.
- Determine whether this should be a new GitHub repo, an existing repo, or a
  subfolder inside an existing repo.
- If a repo exists, run git status --porcelain and git log --oneline -5 first.
- Do not overwrite existing project files without explaining the change.
- If setup files already exist, update them instead of duplicating them.
- Do not start building the actual app unless explicitly told to continue.
- Do not claim files were created, edited, committed, pushed, or tested unless
  the relevant command or tool operation actually happened.

Rules:

1. No phase may exceed 40% of the available context window. Each phase must be
   small enough that a fresh AI session can understand the task, inspect the
   relevant files, complete the work, update documentation, and produce a clean
   handoff.

2. GitHub is the source of truth. All code, trackers, setup docs, install
   instructions, and session logs must live in the repo.

3. Option C hybrid structure applies to all repos:
   - Master phase tracker lives in pagios-ops/trackers/[project]-phase-tracker.md
   - Each project repo gets:
       docs/setup/onboarding.md
       docs/session-logs/
       docs/reference/

4. Repo recommendation. Determine whether this project should:
   - create a new GitHub repository
   - use an existing repository
   - become a subfolder inside an existing repository
   Base the recommendation on project scope, separation of concerns, deployment
   needs, and long-term maintainability.

5. Break the project into phases. Each phase must include:
   - phase number and name
   - objective
   - scope
   - files likely to be created or edited
   - commands likely to be run
   - install or deployment impact
   - testing requirements
   - documentation requirements
   - done criteria
   - estimated context size: small, medium, or large
   - warning if the phase might exceed 40% context window

6. Create onboarding documentation at docs/setup/onboarding.md covering:
   - what the project does
   - where the code lives
   - how to install
   - how to run
   - how to deploy
   - required environment variables
   - important files
   - current phase
   - known blockers
   - next likely step

7. Create install documentation or scripts if this project installs onto a
   server. Any install process must be idempotent where practical.

8. Create phase start briefs for each phase. Each brief must include:
   - what already exists
   - what this phase is supposed to accomplish
   - what files to inspect first
   - what files may need to be edited
   - what commands may be needed
   - what must not be changed
   - how to verify completion
   - what to update before ending the session

9. Do not start building yet unless instructed. Output is the setup plan, repo
   recommendation, phase breakdown, tracker structure, and documentation structure.

Final output format:

Project Name:
Repo Recommendation:
Recommended Repo Name:
Reasoning:
Recommended Folder Structure:
Phase Breakdown:
Tracker File:
Onboarding File:
Install Files:
Phase Start Briefs:
Risks or Warnings:
Verified:
Blocked:
Unverified:
Next Step:

---

PROJECT_NAME=
GITHUB_OWNER=Alijrob
REPO_NAME=
PRIMARY_REPO_URL=
TRACKER_PATH=pagios-ops/trackers/[project]-phase-tracker.md
ONBOARDING_DOC_PATH=docs/setup/onboarding.md
INSTALLER_FILES=
PRIMARY_DOMAIN_OR_DEPLOYMENT_TARGET=
SERVER_PATH=
CURRENT_PHASE=
SESSION_GOAL=
