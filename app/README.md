# WordPress image

`image.txt` pins the official Docker Library WordPress image. The digest was resolved from the `php8.3-apache` manifest on 2026-09-19. A digest fixes identity; it does not prove the image is vulnerability-free.

Only `wp-content` is persisted on EFS. WordPress core is recreated from the selected image on each task start; eight shared authentication keys/salts are injected from the application secret so sessions can work across tasks. Install the first task before enabling scaling to avoid concurrent initialization of an empty filesystem.

Update `image.txt` through a pull request. Review upstream release notes and scan the proposed image (for example, `trivy image --severity HIGH,CRITICAL --exit-code 1 IMAGE`). Rehearse core/database compatibility in the lab, capture a database snapshot and EFS backup, then dispatch the protected deployment workflow. Plugin/theme versions in EFS require a separate controlled update and backup procedure. Rolling back an image does not roll back database migrations or shared content.

Upstream: https://github.com/docker-library/wordpress and https://github.com/docker-library/docs/tree/master/wordpress
