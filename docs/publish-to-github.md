# Publish the portfolio repository

Suggested repository name: `aws-cloud-platform-modernization`.

Suggested description: `Terraform-based AWS WordPress platform with lab/business profiles, security controls, OIDC delivery, and evidence-driven validation.`

Suggested topics: `aws`, `terraform`, `ecs-fargate`, `cloud-security`, `devops`, `solutions-architecture`, `wordpress`, `portfolio`.

1. Extract the ZIP and open the repository root. Read the README and run local checks.
2. Create an empty repository on GitHub. Do not add your original source ZIPs, tfvars, AWS outputs, or state files.
3. Initialize and inspect the commit:

```bash
git init -b main
python scripts/check_secrets.py
git add .
git diff --cached --stat
git diff --cached
git commit -m "Build AWS WordPress platform with lab and business profiles"
```

4. Add the remote for the repository you created and push:

```bash
git remote add origin https://github.com/YOUR-USERNAME/aws-cloud-platform-modernization.git
git push -u origin main
```

5. Review the GitHub Actions CI result. Configure branch protection and the optional deployment environment only after CI is green.
6. Complete a live lab session, publish sanitized evidence, and update the README's status honestly.
7. Add the GitHub link to your resume and LinkedIn Projects section. Use the bullet wording appropriate to the work you personally completed.

No license is selected automatically: choose a license only after confirming you have the right to redistribute any retained upstream/course-derived material. The original course archives are not included.
