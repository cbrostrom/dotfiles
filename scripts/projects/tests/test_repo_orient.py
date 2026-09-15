import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
import importlib.util

_spec = importlib.util.spec_from_file_location("repo_orient", ROOT / "repo-orient.py")
ro = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(ro)


class RepoOrientCapsuleTests(unittest.TestCase):
    def setUp(self) -> None:
        self._old_cache = os.environ.get("HOME")
        self.tmp_home = tempfile.mkdtemp(prefix="repo-orient-home-")
        os.environ["HOME"] = self.tmp_home
        ro.CACHE_BASE = Path(self.tmp_home) / ".cache" / "repo-capsules"
        ro.CACHE_BASE.mkdir(parents=True, exist_ok=True)

    def tearDown(self) -> None:
        if self._old_cache is not None:
            os.environ["HOME"] = self._old_cache

    def _init_repo(self) -> Path:
        td = Path(tempfile.mkdtemp(prefix="repo-orient-git-"))
        subprocess.run(["git", "-C", str(td), "init", "-b", "main"], check=True, capture_output=True)
        (td / "README.md").write_text("# test\n")
        (td / "go.mod").write_text("module example.com/test\n\ngo 1.22\n")
        subprocess.run(["git", "-C", str(td), "add", "."], check=True, capture_output=True)
        subprocess.run(
            ["git", "-C", str(td), "commit", "-m", "init", "--author", "t <t@example.com>"],
            check=True,
            capture_output=True,
            env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.com", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.com", "GIT_COMMITTER_DATE": "2020-01-01T00:00:00"},
        )
        return td

    def test_stable_repo_id_remote(self) -> None:
        repo = self._init_repo()
        subprocess.run(
            ["git", "-C", str(repo), "remote", "add", "origin", "git@github.com:acme/widget.git"],
            check=True,
            capture_output=True,
        )
        sid, source = ro.stable_repo_id(repo)
        self.assertEqual(source, "remote")
        self.assertIn("acme-widget", sid)

    def test_capsule_outside_repository(self) -> None:
        repo = self._init_repo()
        capsule = ro.write_capsule(repo)
        self.assertFalse(str(capsule).startswith(str(repo.resolve())))
        for name in ("manifest.json", "generation.json", "architecture.json", "routes.json"):
            self.assertTrue((capsule / name).is_file())

    def test_fingerprint_changes_on_dirty_tracked(self) -> None:
        repo = self._init_repo()
        clean = ro.build_generation(repo)
        (repo / "README.md").write_text("# changed\n")
        dirty = ro.build_generation(repo)
        self.assertNotEqual(ro.generation_fingerprint(clean), ro.generation_fingerprint(dirty))
        self.assertIn("README.md", dirty["dirty_tracked"])

    def test_untracked_config_fingerprint(self) -> None:
        repo = self._init_repo()
        (repo / "shopify.app.toml").write_text("name = \"x\"\n")
        gen = ro.build_generation(repo)
        self.assertIn("shopify.app.toml", gen["untracked_configs"])

    def test_worktree_detection(self) -> None:
        main = self._init_repo()
        wt = main.parent / "wt-branch"
        subprocess.run(
            ["git", "-C", str(main), "worktree", "add", str(wt), "-b", "feature/wt"],
            check=True,
            capture_output=True,
        )
        self.assertTrue(ro.is_linked_worktree(wt))
        self.assertFalse(ro.is_linked_worktree(main))

    def test_verified_after_ensure(self) -> None:
        repo = self._init_repo()
        capsule = ro.write_capsule(repo)
        status, _ = ro.freshness_status(capsule, repo)
        self.assertEqual(status, "VERIFIED")
        manifest = json.loads((capsule / "manifest.json").read_text())
        self.assertEqual(manifest["plan_id"], "repo-orientation-mvp")



class L0Tests(unittest.TestCase):
    def setUp(self) -> None:
        self._old_cache = os.environ.get("HOME")
        self.tmp_home = tempfile.mkdtemp(prefix="repo-orient-home-")
        os.environ["HOME"] = self.tmp_home
        ro.CACHE_BASE = Path(self.tmp_home) / ".cache" / "repo-capsules"
        ro.CACHE_BASE.mkdir(parents=True, exist_ok=True)

    def tearDown(self) -> None:
        if self._old_cache is not None:
            os.environ["HOME"] = self._old_cache

    def _init_repo(self, node: bool = False) -> Path:
        td = Path(tempfile.mkdtemp(prefix="repo-orient-l0-"))
        subprocess.run(["git", "-C", str(td), "init", "-b", "main"], check=True, capture_output=True)
        (td / "README.md").write_text("# test\n")
        (td / "go.mod").write_text("module example.com/l0\n\ngo 1.22\n")
        (td / "cmd").mkdir()
        (td / "cmd" / "root.go").write_text("package main\n")
        if node:
            (td / "package.json").write_text(json.dumps({"name": "x", "main": "src/main.ts", "scripts": {"test": "vitest", "lint": "eslint ."}}))
            (td / "pnpm-lock.yaml").write_text("lockfileVersion: '9.0'\n")
        subprocess.run(["git", "-C", str(td), "add", "."], check=True, capture_output=True)
        subprocess.run(
            ["git", "-C", str(td), "commit", "-m", "init", "--author", "t <t@example.com>"],
            check=True,
            capture_output=True,
            env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.com", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.com"},
        )
        return td

    def test_l0_deterministic(self) -> None:
        repo = self._init_repo()
        a = json.dumps(ro.build_l0(repo), sort_keys=True)
        b = json.dumps(ro.build_l0(repo), sort_keys=True)
        self.assertEqual(a, b)

    def test_l0_go(self) -> None:
        repo = self._init_repo()
        l0 = ro.build_l0(repo)
        self.assertEqual(l0["stack"], "go")
        self.assertEqual(l0["package_manager"], "go")
        self.assertEqual(l0["go_module"], "example.com/l0")
        self.assertIn("cmd/root.go", l0["entry_points"])
        self.assertIn("go test ./...", l0["commands"])

    def test_l0_node(self) -> None:
        repo = self._init_repo(node=True)
        l0 = ro.build_l0(repo)
        self.assertIn("node", l0["stack"])
        self.assertEqual(l0["package_manager"], "pnpm")
        self.assertIn("src/main.ts", l0["entry_points"])
        self.assertIn("pnpm test", l0["commands"])
        self.assertIn("pnpm lint", l0["commands"])

    def test_l0_never_reads_secrets(self) -> None:
        repo = self._init_repo()
        (repo / ".env").write_text("SECRET_TOKEN=abcdef123456\n")
        (repo / "package.json").write_text(json.dumps({"name": "x", "scripts": {"test": "vitest"}}))
        l0 = json.dumps(ro.build_l0(repo))
        self.assertNotIn("SECRET_TOKEN", l0)
        self.assertNotIn("abcdef123456", l0)



class RoutingTests(unittest.TestCase):
    def setUp(self) -> None:
        self._old_cache = os.environ.get("HOME")
        self.tmp_home = tempfile.mkdtemp(prefix="repo-orient-home-")
        os.environ["HOME"] = self.tmp_home
        ro.CACHE_BASE = Path(self.tmp_home) / ".cache" / "repo-capsules"
        ro.CACHE_BASE.mkdir(parents=True, exist_ok=True)
        td = Path(tempfile.mkdtemp(prefix="repo-orient-route-"))
        self.repo = td
        subprocess.run(["git", "-C", str(td), "init", "-b", "main"], check=True, capture_output=True)
        (td / "internal").mkdir()
        (td / "internal" / "core.go").write_text("package internal\n")
        (td / "internal" / "core_test.go").write_text("package internal\n")
        (td / "cmd").mkdir()
        (td / "cmd" / "serve.go").write_text("package main\n")
        (td / "go.mod").write_text("module example.com/route\n\ngo 1.22\n")
        subprocess.run(["git", "-C", str(td), "add", "."], check=True, capture_output=True)
        subprocess.run(
            ["git", "-C", str(td), "commit", "-m", "init", "--author", "t <t@example.com>"],
            check=True,
            capture_output=True,
            env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.com", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.com"},
        )

    def tearDown(self) -> None:
        if self._old_cache is not None:
            os.environ["HOME"] = self._old_cache

    def test_route_returns_bounded_existing_paths(self) -> None:
        packet = ro.route_task(self.repo, "fix the core parser")
        self.assertGreaterEqual(len(packet["read_next"]), 1)
        self.assertLessEqual(len(packet["read_next"]), 3)
        for r in packet["read_next"]:
            self.assertTrue((self.repo / r["path"]).is_file())
            self.assertTrue(r.get("reason"))

    def test_route_output_within_budget(self) -> None:
        packet = ro.route_task(self.repo, "fix the core parser")
        self.assertLessEqual(len(json.dumps(packet)), ro.MAX_OUTPUT_BUDGET_CHARS)

    def test_route_no_term_match_falls_back(self) -> None:
        packet = ro.route_task(self.repo, "completely unrelated gibberish xyzzy")
        self.assertGreaterEqual(len(packet["read_next"]), 1)
        for r in packet["read_next"]:
            self.assertTrue((self.repo / r["path"]).is_file())

    def test_route_includes_commands_and_skip(self) -> None:
        packet = ro.route_task(self.repo, "core parser")
        self.assertIn("go test ./...", packet["commands"])
        self.assertTrue("skip" in packet)

    def test_route_deterministic(self) -> None:
        a = json.dumps(ro.route_task(self.repo, "core parser"), sort_keys=True)
        b = json.dumps(ro.route_task(self.repo, "core parser"), sort_keys=True)
        self.assertEqual(a, b)



class GraphTests(unittest.TestCase):
    def setUp(self) -> None:
        self._old_cache = os.environ.get("HOME")
        self.tmp_home = tempfile.mkdtemp(prefix="repo-orient-home-")
        os.environ["HOME"] = self.tmp_home
        ro.CACHE_BASE = Path(self.tmp_home) / ".cache" / "repo-capsules"
        ro.CACHE_BASE.mkdir(parents=True, exist_ok=True)
        td = Path(tempfile.mkdtemp(prefix="repo-orient-graph-"))
        self.repo = td
        subprocess.run(["git", "-C", str(td), "init", "-b", "main"], check=True, capture_output=True)
        (td / "parser.go").write_text("package main\n")
        (td / "router.go").write_text("package main\n")
        (td / "go.mod").write_text("module example.com/g\n\ngo 1.22\n")
        subprocess.run(["git", "-C", str(td), "add", "."], check=True, capture_output=True)
        subprocess.run(
            ["git", "-C", str(td), "commit", "-m", "init", "--author", "t <t@example.com>"],
            check=True,
            capture_output=True,
            env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.com", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.com"},
        )

    def tearDown(self) -> None:
        if self._old_cache is not None:
            os.environ["HOME"] = self._old_cache

    def test_graph_boost_reorders_routes(self) -> None:
        packet = ro.route_task(self.repo, "router wiring", graph=[{"file": "router.go", "qualified_name": "Route"}])
        paths = [r["path"] for r in packet["read_next"]]
        self.assertEqual(paths[0], "router.go")

    def test_graph_none_falls_back_cleanly(self) -> None:
        packet = ro.route_task(self.repo, "parser", graph=None)
        self.assertGreaterEqual(len(packet["read_next"]), 1)

    def test_graph_candidates_handles_missing_mcporter(self) -> None:
        # mcporter almost certainly absent in sandbox PATH; must return None, not raise
        result = ro.graph_candidates(self.repo, ["parser"], timeout=2)
        self.assertTrue(result is None or isinstance(result, list))

    def test_cbm_project_name(self) -> None:
        self.assertEqual(ro.cbm_project_name(Path("/Users/x/y")), "Users-x-y")


if __name__ == "__main__":
    unittest.main()
