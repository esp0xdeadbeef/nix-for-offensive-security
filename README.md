
# Welcome to the presentation about

# Nix

This is not NixOS.

To be clear:

Codenixos != nix != home-manager

This talk is about Nix as a development environment tool for offensive security.

* * *

# The Problem

As offensive security consultants, we constantly deal with legacy tooling.

Old exploits.  
Unmaintained PoCs.  
Python2 scripts from 2010.  
C code written against ancient libraries.

And we try to run them on a modern system.

That is where things break.

* * *

# What Goes Wrong on a Normal OS

You clone an exploit.

You try to compile it.

And then:

* GCC is too new
    
* Warnings are now errors
    
* Deprecated APIs are removed
    
* OpenSSL headers have changed
    
* Struct layouts differ
    
* The build system assumes autotools from 2008
    
* The exploit expects Python 2.6
    
* Your system only ships Python 3.11
    

Or worse:

The C extension builds successfully, but crashes at runtime due to ABI mismatch.

Now what?

* * *

# Traditional Fixes

You have a few options.

### Option 1: Pollute your host

Install:

* Old Python
    
* Old pip
    
* Old OpenSSL
    
* Old libpcap
    
* Old GCC
    

Now your workstation is unstable.

And you forgot what you changed.

* * *

### Option 2: Use Docker

Build a Dockerfile.

Install everything inside it.

Rebuild the image every time you tweak something.

Now you have:

* Duplicate toolchains
    
* No direct hardware access
    
* USB passthrough issues
    
* Networking edge cases
    
* Kernel module limitations
    
* Weird debugging friction
    

And when you need gdb, strace, or perf, you end up installing them inside the container too.

* * *

### Option 3: Spin up an old VM

Install Ubuntu 12.04.

Disable updates.

Hope nothing breaks.

Now you maintain a museum piece.

* * *

# The Real Problem

The real problem is not that the exploit is old.

The real problem is that your environment is not reproducible.

Your system evolves.

The exploit does not.

Every year the gap widens.

* * *

# What We Actually Want

We want:

* Old toolchains
    
* Old Python versions
    
* Old libraries
    
* Deterministic builds
    
* No pollution of our host
    
* Direct hardware access
    

All at the same time.

That combination is rare.

* * *

# Enter Nix

Nix lets you describe an environment declaratively.

Not a container.

Not a VM.

An environment.

You define:

* Python 2.7
    
* Python 3.6
    
* Specific nixpkgs commit
    
* Specific lorcon commit
    
* Exact dependency versions
    

Then you run:

Codenix develop

And you enter that exact environment.

No system pollution.

No global installs.

No guessing which library version you are using.

* * *

# Demo Scenario

Let’s create a legacy exploit lab.

2012 is arbitrary. It just gives us plenty of Python2 code.

```bash
searchsploit ' ' --cve '2012' \  
| grep py \  
| cut -d '|' -f 2 \  
| sort -u \  
| while read line; do searchsploit -m $line ; done
```

Now we have a pile of old Python exploits.

Most of them break immediately.

* Missing requests.  
* Missing Crypto.  
* Boken C extensions.  
* Python2 syntax issues.

And then we hit this:

```bash
python3 ./22739.py wlp0<redacted>
```

It fails with:

```bash
CodePyLorcon2.Lorcon2Exception:  
failed to create monitor interface wlp0<redacted>:wlp0<redacted>
```

This exploit depends on:

* PyLorcon2
    
* libpcap
    
* libnl
    
* Monitor mode
    
* Packet injection
    

On my machine it fails.

Not because the environment is wrong.

Because my WiFi card does not support packet injection.

That is a real failure.

Not an environment failure.

* * *

# Why This Matters in Offensive Work

In offensive security, clarity matters.

If an exploit fails, you want to know why.

Was it patched?  
Was it mitigated?  
Did the target change?

Or did your system just update OpenSSL last week?

With Nix, the environment is pinned.

If something breaks, the breakage is meaningful.

Reproducibility is not convenience.

It is analytical integrity.


# Using the Lab Directly from GitHub

You do not need to clone the repository.

You can enter the environment directly from GitHub:

Codenix develop github:esp0xdeadbeef/nix-for-offensive-security

That command:

* Downloads the flake
    
* Resolves the pinned nixpkgs commit
    
* Builds the declared environment
    
* Drops you into the dev shell
    

No global installs.  
No Dockerfile.  
No manual dependency resolution.

You can even pin a specific revision:

Codenix develop github:esp0xdeadbeef/nix-for-offensive-security/<commit>

That guarantees you are using the exact same environment as the author at that commit.

* * *

# What Happens Under the Hood

When you run `nix develop`:

* Dependencies are downloaded into the Nix store
    
* Everything is stored under `/nix/store`
    
* Each dependency is content-addressed
    
* Nothing touches your global system libraries
    

Your host remains clean.

* * *

# Cleaning Up After Yourself

One common concern is:

“Does this fill my disk?”

Yes, the Nix store grows over time.

But Nix gives you explicit control.

* * *

## Remove Unused Dependencies

After you are done with a lab:

Codenix-collect-garbage -d

This deletes all unused generations and unreferenced store paths.

It is safe.  
It does not break your system.  
It only removes things that are no longer referenced.

* * *

## See What Is Taking Space

You can inspect store usage:

Codedu -sh /nix/store

Or more detailed:

Codenix path-info -Sh /nix/store/*

* * *

## Why This Is Different from Docker

With Docker:

* Layers accumulate
    
* Images stack
    
* Dangling images remain
    
* Cleaning requires manual pruning
    

With Nix:

* Everything is reference counted
    
* Garbage collection is deterministic
    
* If nothing depends on it, it can be removed
    

* * *

# Clean Workflow Example

1. Enter environment:
    

```bash
nix develop github:esp0xdeadbeef/nix-for-offensive-security
```

2. Run exploits, test tooling.
    
3. Exit shell.
    
4. Clean up:
    
```bash
nix-collect-garbage -d
```

System returns to previous state.

No lingering Python installs.  
No broken OpenSSL versions.  
No global state changes.

* * *

# Important Note

Nix does not uninstall packages in the traditional sense.

It removes store paths that are no longer reachable.

That means you can always:

* Re-enter the environment
    
* Rebuild it
    
* Get the exact same result
    

Reproducibility includes cleanup.

* * *

# Reproducible Nix Flakes with flake.lock

Running `nix flake update` refreshes your inputs and rewrites `flake.lock` with exact pinned revisions. That file captures the full dependency graph used for the build.

Committing `flake.lock` ensures deterministic builds across machines and CI. Without it, dependencies drift and reproducibility is lost.

