"""
Git Yönetim Modülü
"""

from pathlib import Path
from typing import Optional, Tuple
import logging
from git import Repo, GitCommandError

logger = logging.getLogger(__name__)


class GitManager:
    """Git repository yöneticisi"""
    
    def clone_repository(
        self,
        repo_url: str,
        target_path: Path,
        branch: str = "main"
    ) -> bool:
        """Repository'yi klonla"""
        try:
            # Dizin varsa sil
            if target_path.exists():
                import shutil
                shutil.rmtree(target_path)
            
            # Repository'yi klonla
            Repo.clone_from(
                repo_url,
                target_path,
                branch=branch,
                depth=1  # Sadece son commit
            )
            
            logger.info(f"Repository klonlandı: {repo_url} -> {target_path}")
            return True
            
        except GitCommandError as e:
            logger.error(f"Git klonlama hatası: {e}")
            return False
        except Exception as e:
            logger.error(f"Repository klonlama hatası: {e}")
            return False
    
    def pull_latest(self, repo_path: Path, branch: Optional[str] = None) -> Tuple[bool, str]:
        """Son değişiklikleri çek"""
        try:
            repo = Repo(repo_path)
            origin = repo.remotes.origin
            
            # Branch değiştir (gerekirse)
            if branch and repo.active_branch.name != branch:
                repo.git.checkout(branch)
            
            # Pull
            pull_info = origin.pull()
            
            if pull_info:
                commit_info = pull_info[0]
                message = f"Güncellendi: {commit_info.commit.hexsha[:7]}"
                logger.info(f"Repository güncellendi: {repo_path}")
                return True, message
            
            return True, "Zaten güncel"
            
        except GitCommandError as e:
            error_msg = f"Git pull hatası: {e}"
            logger.error(error_msg)
            return False, error_msg
        except Exception as e:
            error_msg = f"Repository güncelleme hatası: {e}"
            logger.error(error_msg)
            return False, error_msg
    
    def get_current_commit(self, repo_path: Path) -> Optional[str]:
        """Mevcut commit hash'ini al"""
        try:
            repo = Repo(repo_path)
            return repo.head.commit.hexsha
        except Exception as e:
            logger.error(f"Commit hash alma hatası: {e}")
            return None
    
    def get_current_branch(self, repo_path: Path) -> Optional[str]:
        """Mevcut branch'i al"""
        try:
            repo = Repo(repo_path)
            return repo.active_branch.name
        except Exception as e:
            logger.error(f"Branch alma hatası: {e}")
            return None
    
    def checkout_commit(self, repo_path: Path, commit_hash: str) -> bool:
        """Belirli bir commit'e geç"""
        try:
            repo = Repo(repo_path)
            repo.git.checkout(commit_hash)
            logger.info(f"Commit checkout: {commit_hash}")
            return True
        except GitCommandError as e:
            logger.error(f"Checkout hatası: {e}")
            return False
    
    def reset_to_previous(self, repo_path: Path) -> bool:
        """Önceki commit'e dön"""
        try:
            repo = Repo(repo_path)
            repo.git.reset('--hard', 'HEAD~1')
            logger.info("Repository önceki commit'e döndürüldü")
            return True
        except GitCommandError as e:
            logger.error(f"Reset hatası: {e}")
            return False
    
    def get_commit_log(self, repo_path: Path, count: int = 10) -> list:
        """Commit geçmişini al"""
        try:
            repo = Repo(repo_path)
            commits = []
            
            for commit in repo.iter_commits(max_count=count):
                commits.append({
                    'hash': commit.hexsha[:7],
                    'message': commit.message.strip(),
                    'author': str(commit.author),
                    'date': commit.committed_datetime.isoformat()
                })
            
            return commits
        except Exception as e:
            logger.error(f"Commit log alma hatası: {e}")
            return []
    
    def has_changes(self, repo_path: Path) -> bool:
        """Değişiklik var mı kontrol et"""
        try:
            repo = Repo(repo_path)
            return repo.is_dirty()
        except Exception as e:
            logger.error(f"Değişiklik kontrolü hatası: {e}")
            return False

