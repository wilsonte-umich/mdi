#---------------------------------------------------------------------------
# MDI command line installation utility
#---------------------------------------------------------------------------

# -----------------------------------------------------------------------
# ensure that we are working in an 'mdi' directory that contains this script
# -----------------------------------------------------------------------
export MDI_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
if [[ "$MDI_DIR" != */mdi ]]; then
    echo
    echo "ERROR - this script must be run from within an 'mdi' folder than contains it"
    echo
    exit 1
fi
cd $MDI_DIR

# -----------------------------------------------------------------------
# prompt for the requested installation action
# -----------------------------------------------------------------------
echo
echo "Welcome to the Michigan Data Interface installation utility."
echo
echo "What would you like to install?"
echo
echo "  1 - MDI Stage 1 pipelines only; Stage2 apps will be skipped"
echo "  2 - both Stage 1 pipelines and Stage 2 apps (requires R in PATH)"
echo "  3 - exit and do nothing"
echo
echo "Please note that Stage 2 apps installation takes many minutes."
echo "Select option 1 if you do not intend to use interactive web tools"
echo "from this MDI installation."
echo
echo "For details, see: https://midataint.github.io/"
echo
echo "Select an action by its number: "
read ACTION_NUMBER
echo

# -----------------------------------------------------------------------
# install Stage 1 pipelines only; R is not required
# -----------------------------------------------------------------------
if [ "$ACTION_NUMBER" = "1" ]; then

    # initialize the MDI directory tree
    echo "initializing the MDI file tree"
    mkdir -p config # populated below
    mkdir -p data   # unused, this is a pipelines-only installation
    mkdir -p environments # populated by Stage 1 pipelines conda create
    mkdir -p frameworks/definitive      # populated below
    mkdir -p frameworks/developer-forks # unused, pipelines-only installation assumed to be an end user
    mkdir -p library   # unused, this is a pipelines-only installation
    mkdir -p remote    # populated below
    mkdir -p resources # populated by user as needed
    mkdir -p sessions  # unused, this is a pipelines-only installation
    mkdir -p suites/definitive      # populated by user via mdi add or other means
    mkdir -p suites/developer-forks # unused, pipelines-only installation assumed to be an end user

    # clone/pull the mdi-manager repository to access its file resources
    echo "cloning/updating the mdi-manager repository"
    function updateRepo {
        PARENT_FOLDER=$1
        REPO=$2
        URL=$3
        CHECKOUT=$4
        FOLDER=$PARENT_FOLDER/$REPO
        if [ -d $FOLDER ]; then
            cd $FOLDER
            git checkout main
            git pull
        else
            cd $PARENT_FOLDER
            git clone $URL
            cd $REPO
        fi
        if [ "$CHECKOUT" = "latest" ]; then
            CHECKOUT=`git tag -l --sort=-v:refname | head -n1` # the latest tagged version
        fi
        echo "checking out $CHECKOUT"
        git checkout $CHECKOUT
        cd $MDI_DIR
    }
    MDI_MANAGER=mdi-manager
    updateRepo $MDI_DIR $MDI_MANAGER https://github.com/MiDataInt/$MDI_MANAGER.git main

    # initialize the installation config files if missing, but do not overwrite existing
    echo "initializing config files"
    INST_CONFIG=$MDI_MANAGER/inst/config
    function cpConfigFile {
        SOURCE=$INST_CONFIG/$1
        DESTINATION=config/$1
        if [ ! -e $DESTINATION ]; then cp $SOURCE $DESTINATION; fi
    }
    CONFIG_FILES=`ls -1 $INST_CONFIG`
    for CONFIG_FILE in $CONFIG_FILES; do cpConfigFile $CONFIG_FILE; done

    # initialize/update the remote server scripts
    echo "initializing remote scripts"
    cp -f $MDI_MANAGER/inst/remote/* remote 

    # initialize/update the mdi command line utility   
    echo "initializing 'mdi' command line utility"
    cp -f $MDI_MANAGER/inst/mdi mdi   
    chmod ug+x mdi 

    # add MDI_DIR to PATH via ~/.bashrc; do not overwrite if already present
    echo "checking for mdi directory in PATH"
    head="# >>> mdi initialize >>>"
    notice="# !! Contents within this block are managed by 'mdi initialize' !!"
    path='export PATH='$MDI_DIR':$PATH'
    tail="# <<< mdi initialize <<<"
    payload="$head\n$notice\n$path\n$tail"
    bashRcFile=~/.bashrc
    bashRcBackup=$bashRcFile.mdi-backup
    bashRcContents=""
    match=""
    if [ -e $bashRcFile ]; then 
        cp $bashRcFile $bashRcBackup
        bashRcContents=`sed 's/\r//g' $bashRcFile`
        match=`grep "$head" $bashRcFile`
    fi
    if [ "$match" = "" ]; then
        echo "adding mdi directory to PATH via ~/.bashrc"
        bashRcContents="$bashRcContents\n\n$payload"
        echo -e $bashRcContents | sed 's/\n\n\n/\n\n/g' > $bashRcFile
    fi

    # clone/pull the definitive pipelines framework repostory
    # apps framework not needed as this is a pipelines-only installation
    echo "cloning/updating the mdi-pipelines-framework repository"
    PIPELINES_FRAMEWORK=mdi-pipelines-framework
    FRAMEWORKS_DIR=$MDI_DIR/frameworks/definitive
    updateRepo $FRAMEWORKS_DIR $PIPELINES_FRAMEWORK https://github.com/MiDataInt/$PIPELINES_FRAMEWORK.git latest

    # initialize the pipelines jobManager
    JOB_MANAGER_DIR=$FRAMEWORKS_DIR/$PIPELINES_FRAMEWORK/job_manager
    perl $JOB_MANAGER_DIR/initialize.pl $MDI_DIR

    # finish up
    echo DONE

# -----------------------------------------------------------------------
# Stage 2 apps requested; use full mdi::install() from the mdi-manager R package
# -----------------------------------------------------------------------
elif [ "$ACTION_NUMBER" = "2" ]; then
    CRAN_REPO=https://repo.miserver.it.umich.edu/cran/
    Rscript -e "install.packages('remotes', repos = '$CRAN_REPO')"  
    Rscript -e "remotes::install_github('MiDataInt/mdi-manager')"  
    Rscript -e "mdi::install('$MDI_DIR', confirm = FALSE)"
    echo DONE
fi
