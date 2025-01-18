# lib.sh
# meant to be included in other scripts and not run directly
# source ./lib.sh

start_app() {
    pushd "$1"
    if ! docker-compose ps | grep -q 'Up'; then
        echo "Docker Compose project is not running. Starting it..."
        docker-compose up -d
        echo "$1 started."
    else
        echo "$1 is already running."
    fi

    popd
}

install_default_config(app, filename) {
    if [ -n "$2" ]; then
        cp "$1/config/$2.default" "$1/config/$2"
        echo "Installed $1/config/$2 - you should review this file for possible configuration changes"
    fi

    if [ -f "$1/.env.example" ]; then
	cp "$1/.env.example" "$1/.env"
        echo "installed $1/.env - you should review this file for possible configuration changes"
    fi
}
