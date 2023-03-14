## Parse the build environment

# General Nix values
let sandbox = $env.NIX_BUILD_TOP # Sandbox directory
let drvName = $env.name
let drvSrc = $env.src
let drvOut = $env.out
let drvSystem = $env.system
let drvBuildScript = $env.build
let nixStore = $env.NIX_STORE

# Nushell-specific values
let packages = ($env.__nu_packages | split row " ")
let nushellVersion = $env.__nu_nushell_version
let envFile = $env.__nu_envFile

# Helper values
let numPackages = ($packages | length) # Total # of packages added to the env

let packagesPath = (
  $packages
  | each { |pkg| $"($pkg)/bin" } # Append /bin to each package path
  | str collect (char esep)      # Collect into a single colon-separate string
)

let srcs = glob $"($drvSrc)/**/*" # Sources to copy into sandbox

### Helper functions

## Logging

def color [color: string, msg: string] { echo $"(ansi $color)($msg)(ansi reset)" }
def blue [msg: string] { color "blue" $msg }
def green [msg: string] { color "green" $msg }
def purple [msg: string] { color "purple" $msg }
def red [msg: string] { color "red" $msg }
def teal [msg: string] { color "teal" $msg }

# Splashy, colored banner text
def banner [text: string] { echo $"(red ">>>") (green $text)" }

## Derivation stuff

# Run a derivation phase (skip if empty)
def runPhase [
  name: string,
  phase: string,
] {
  if $phase != "" {
    echo $"(blue ">>") Running (purple $name) phase"

    # We need to source the envFile prior to each phase so that custom Nushell
    # commands are registered. Right now there's a single env file but in
    #$ principle there could be multiple.
    nu --config $envFile --commands $phase
  } else {
    echo $"Skipping (purple $name) phase"
  }
}

## Provide info about the current derivation
banner "INFO"

# Display Nushell version
echo $"Running Nushell (blue $nushellVersion)"

# Display info about the derivation
echo "Derivation info:"

{
  name: $drvName,
  src: $drvSrc,
  out: $drvOut,
  system: $drvSystem
} | table

## Set up the environment
banner "SETUP"

# Create the output directory (realisation fails otherwise)
mkdir $drvOut

# Add packages to PATH
echo $"Adding (teal $numPackages) packages to PATH"
let-env PATH = $packagesPath

# Copy sources
echo "Copying sources"

$srcs | each { |src| cp -r $src $sandbox }

## The realisation process (only two phases for now, but there could be more)
banner "REALISATION"

runPhase "build" $drvBuildScript

## Run if realisation succeeds
banner "DONE!"

echo $"Output written to ($drvOut)"
