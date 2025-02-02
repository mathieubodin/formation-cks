# Image Footprint

- Containers and Docker
- Reduce Image Size (Multi-Stage)
- Secure Images

## Containers and Docker

- Containers are a way to package software in a format that can run isolated on a shared operating system.
- Containers are lightweight because they don't need the extra load of a hypervisor, but run directly within the host machine's kernel.
- Containers are separated from each other and from the host machine to guarantee that they are isolated from each other, through the use of *kernel groups*.
- Containers are built from images that specify their precise contents. Images are built from layers that are stacked on top of each other. Each layer depends on the layer below it.
- Docker is a tool that automates the deployment of applications inside software containers. It uses a Dockerfile to describe how the layers are stacked.
- Dockerfiles are text files that contain the commands used to describe the layers in the image. Some of them would create layers, while others would create temporary images that would not increase the size of the final image.

## Reduce Image Size (Multi-Stage)

The idea behind multi-stage builds is to use multiple `FROM` statements in a single `Dockerfile`. Each `FROM` statement starts a new stage, and the final image is built from the last stage. The intermediate stages are not included in the final image, which reduces the size of the final image.

Thus, multi-stage builds are a way to reduce the size of the final image by using intermediate images that are not included in the final image. This is useful when you need to build an image that requires a lot of dependencies, but you don't want to include those dependencies in the final image.

### Hands-on multi-stage build

First, we'll work with a simple example.

```shell
# Connect to the Vagrant VM
vagrant ssh vm1
# Move to the directory
cd 18-image-footprint/docker
# Build the image
sudo docker build -t app .
# Run the container
sudo docker run app
```

Check the image size with `sudo docker images`. It's pretty heavy. Let's try to reduce it with a multi-stage build.

Update the `Dockerfile` and add another `FROM` section:

```dockerfile
# ...
RUN CGO_ENABLED=0 go build app.go

FROM alpine
COPY --from=0 /app .

CMD ["./app"]
```

Now, build the image again:

```shell
sudo docker build -t app .
```

Check the image size again. It should be much smaller.

## Secure Images

- Keep images up to date: Regularly update the base image and dependencies.
- Use official images: Use official images from trusted sources. They are more likely to be secure and up to date.
- Use tagged images: Use tagged images to ensure that you are using a specific version of the image.
- Scan images: Use tools like Clair, Trivy, or Anchore to scan images for vulnerabilities.
- Use versioned packages: Use versioned packages to ensure that you are using a specific version of the package.
- Use minimal images: Use minimal images to reduce the attack surface.

### Extra: analyse image with Trivy

Resources:

- [Installing Trivy](https://trivy.dev/latest/getting-started/installation/#debianubuntu-official)

#### Install Trivy

```shell
# Connect to the Vagrant VM
vagrant ssh vm1
# Install Trivy
sudo apt-get install wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy
```

Run Trivy to scan the image:

```shell
sudo trivy image app --ignore-unfixed --severity HIGH,CRITICAL --format json --output extra-trivy/app_docker-image__trivy.json
```
