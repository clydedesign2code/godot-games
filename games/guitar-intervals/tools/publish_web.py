"""Build the guitar prototype and publish its static files to the project's Pages branch."""
import argparse
import hashlib
import http.client
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
from urllib.error import URLError
from urllib.request import Request, urlopen


GAME = Path(__file__).resolve().parents[1]
REMOTE = "https://github.com/clydedesign2code/godot-games.git"
BRANCH = "gh-pages"
URL = "https://clydedesign2code.github.io/godot-games/guitar-intervals/"
FILES = ("index.html", "index.js", "index.wasm", "index.pck", "index.png",
         "index.audio.worklet.js", "index.audio.position.worklet.js", "licenses.txt")


def deploy(build, checkout):
    digest = hashlib.sha256()
    for name in FILES:
        digest.update(hashlib.sha256((build / name).read_bytes()).digest())
    version = digest.hexdigest()[:16]
    shell = (build / "index.html").read_text()
    if "<head>" not in shell or "<base " in shell:
        raise ValueError("Unexpected Godot Web shell. Check relative resource URLs before publishing.")

    def git(*args, **kwargs):
        return subprocess.run(["git", *args], cwd=checkout, check=True, **kwargs)

    git("init", "-q", "-b", BRANCH)
    git("remote", "add", "origin", REMOTE)
    remote_branch = git("ls-remote", "--heads", "origin", "refs/heads/" + BRANCH,
                        capture_output=True, text=True).stdout
    if remote_branch:
        git("fetch", "-q", "--depth=1", "origin", "refs/heads/" + BRANCH)
        git("merge", "--ff-only", "FETCH_HEAD")

    site = checkout / "guitar-intervals"
    marker = site / "build.txt"
    if site.exists() and not marker.is_file():
        raise RuntimeError("The Pages directory already has content from another publisher.")
    previous = marker.read_text().strip() if marker.exists() else ""
    if previous == version:
        return version
    releases = site / "builds"
    target = releases / version
    target.mkdir(parents=True, exist_ok=True)
    for name in FILES:
        shutil.copyfile(build / name, target / name)
    # A cached landing page can finish loading its own matching runtime and pack.
    (site / "index.html").write_text(shell.replace(
        "<head>", f'<head>\n\t<base href="./builds/{version}/">', 1))
    marker.write_text(version + "\n")
    for folder in releases.iterdir():
        if folder.name not in {previous, version} and len(folder.name) == 16 and all(
                ch in "0123456789abcdef" for ch in folder.name) and folder.is_dir():
            shutil.rmtree(folder)
    (checkout / ".nojekyll").touch()
    git("add", "--", ".nojekyll", "guitar-intervals/")
    git("-c", "user.name=Fret Relations Web", "-c", "user.email=web@fret-relations.invalid",
        "commit", "-q", "-m", "Publish guitar prototype " + version)
    git("push", "origin", "HEAD:refs/heads/" + BRANCH)
    return version


def verify_live(build, version):
    pack_hash = hashlib.sha256((build / "index.pck").read_bytes()).digest()
    base = f"builds/{version}/"
    deadline = time.monotonic() + 360
    last_error = "waiting for the new landing page"
    print("Checking the live Pages deployment…", flush=True)
    while time.monotonic() < deadline:
        try:
            with urlopen(URL + "?v=" + version, timeout=15) as response:
                if f'<base href="./{base}">'.encode() not in response.read():
                    raise ValueError("the previous version is still being served")
            with urlopen(URL + base + "index.pck", timeout=30) as response:
                if hashlib.sha256(response.read()).digest() != pack_hash:
                    raise ValueError("the deployed Godot pack differs from the export")
            request = Request(URL + base + "index.wasm", headers={"Range": "bytes=0-3"})
            with urlopen(request, timeout=15) as response:
                if response.headers.get_content_type() != "application/wasm" or response.read(4) != b"\x00asm":
                    raise ValueError("the server did not return the WebAssembly runtime")
            print(f"Verified: {URL}?v={version}")
            return
        except (URLError, TimeoutError, http.client.HTTPException, ValueError) as error:
            last_error = str(error)
            time.sleep(6)
    raise SystemExit("Push succeeded but Pages verification timed out: " + last_error)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-dir", type=Path, help="Publish an already-tested Web export")
    options = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="fr12-pages-") as scratch:
        work = Path(scratch)
        build = options.build_dir or work / "export"
        if options.build_dir is None:
            subprocess.run([GAME / "tools/build_web.sh", build], check=True)
        repo = work / "pages"
        repo.mkdir()
        verify_live(build, deploy(build, repo))
