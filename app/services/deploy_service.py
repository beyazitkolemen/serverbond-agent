import os
import subprocess
import time
from typing import Dict, Optional
from app.core.logger import logger
from app.services.docker_service import DockerService


class DeployService:
    """Service for deploying projects from Git repositories"""
    
    def __init__(self):
        self.docker_service = DockerService()
        self.base_path = "/srv/serverbond"
        self.sites_path = f"{self.base_path}/sites"
        self.logs_path = f"{self.base_path}/logs"
        
        # Create directories if they don't exist
        os.makedirs(self.sites_path, exist_ok=True)
        os.makedirs(self.logs_path, exist_ok=True)
    
    def deploy_project(
        self,
        project: str,
        repository: str,
        branch: str,
        project_type: str,
        domain: str,
        env: Dict[str, str]
    ):
        """Deploy a project from Git repository"""
        log_file = f"{self.logs_path}/{project}.log"
        
        try:
            with open(log_file, 'w') as log:
                self._log(log, f"Starting deployment for {project}")
                self._log(log, f"Repository: {repository}")
                self._log(log, f"Branch: {branch}")
                self._log(log, f"Type: {project_type}")
                
                # Step 1: Clone repository
                project_path = f"{self.sites_path}/{project}"
                if os.path.exists(project_path):
                    self._log(log, f"Removing existing directory: {project_path}")
                    subprocess.run(["rm", "-rf", project_path], check=True)
                
                self._log(log, "Cloning repository...")
                result = subprocess.run(
                    ["git", "clone", "--branch", branch, repository, project_path],
                    capture_output=True,
                    text=True
                )
                
                if result.returncode != 0:
                    self._log(log, f"Git clone failed: {result.stderr}")
                    raise Exception(f"Git clone failed: {result.stderr}")
                
                self._log(log, "Repository cloned successfully")
                
                # Step 2: Build Docker image
                self._log(log, "Building Docker image...")
                image_name = f"{project}:latest"
                
                if self._has_dockerfile(project_path):
                    self._build_with_dockerfile(log, project_path, image_name)
                else:
                    self._build_with_railpack(log, project_path, image_name, project_type)
                
                # Step 3: Start container with Traefik labels
                self._log(log, "Starting container...")
                self._start_container(log, project, image_name, domain, env)
                
                self._log(log, f"Deployment complete! Site available at: {domain}")
                
        except Exception as e:
            logger.error(f"Deployment failed for {project}: {str(e)}")
            with open(log_file, 'a') as log:
                self._log(log, f"DEPLOYMENT FAILED: {str(e)}")
    
    def _log(self, file, message: str):
        """Write log message"""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        line = f"[{timestamp}] {message}\n"
        file.write(line)
        file.flush()
        logger.info(f"{message}")
    
    def _has_dockerfile(self, path: str) -> bool:
        """Check if project has a Dockerfile"""
        return os.path.exists(f"{path}/Dockerfile")
    
    def _build_with_dockerfile(self, log, path: str, image_name: str):
        """Build using existing Dockerfile"""
        self._log(log, "Using existing Dockerfile")
        
        result = subprocess.run(
            ["docker", "build", "-t", image_name, path],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            self._log(log, f"Docker build failed: {result.stderr}")
            raise Exception(f"Docker build failed: {result.stderr}")
        
        self._log(log, "Docker image built successfully")
    
    def _build_with_railpack(self, log, path: str, image_name: str, project_type: str):
        """Build using railpack or nixpacks"""
        self._log(log, f"Building with railpack ({project_type})")
        
        # Check if railpack is available
        railpack_available = subprocess.run(
            ["which", "railpack"],
            capture_output=True
        ).returncode == 0
        
        if railpack_available:
            result = subprocess.run(
                ["railpack", "build", path, "-t", image_name],
                capture_output=True,
                text=True
            )
        else:
            # Fallback to nixpacks
            self._log(log, "railpack not found, using nixpacks")
            result = subprocess.run(
                ["nixpacks", "build", path, "-t", image_name],
                capture_output=True,
                text=True
            )
        
        if result.returncode != 0:
            self._log(log, f"Build failed: {result.stderr}")
            raise Exception(f"Build failed: {result.stderr}")
        
        self._log(log, "Image built successfully")
    
    def _start_container(
        self,
        log,
        project: str,
        image_name: str,
        domain: str,
        env: Dict[str, str]
    ):
        """Start container with Traefik labels"""
        
        # Prepare environment variables
        environment = env.copy()
        
        # Prepare Traefik labels
        labels = {
            "traefik.enable": "true",
            "traefik.http.routers.{}.rule".format(project): f"Host(`{domain}`)",
            "traefik.http.services.{}.loadbalancer.server.port".format(project): "80",
            "serverbond.project": project,
            "serverbond.domain": domain
        }
        
        # Create container
        container = self.docker_service.create_container(
            image=image_name,
            name=project,
            environment=environment,
            labels=labels,
            restart_policy={"Name": "unless-stopped"}
        )
        
        self._log(log, f"Container started: {container['id']}")

