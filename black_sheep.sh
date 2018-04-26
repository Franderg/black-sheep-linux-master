#!/bin/bash

##########################
# Variables              #
##########################

INSTALL='sudo install --owner=root --group=root --mode=644'


##########################
# Check permissions      #
##########################

# Check for permissions errors
if [ `id -u` == 0 ]; then
    echo "[ERROR] This script should not be executed as root. Run it a a sudo-capable user."
    exit 1
fi

# Check if user can do sudo
echo "This application needs root privileges."
if [ `sudo id -u` != 0 ]; then
    echo "This user cannot cast sudo or you typed an incorrect password (several times)."
    exit 1
else
    echo "Correctly authenticated."
fi

##########################
# Station configuration  #
##########################


function hostname {

    # Instala el script de cambio de nombre de estacion
    $INSTALL ./conf/sbin/changehostname /sbin/changehostname
    sudo chmod 755 /sbin/changehostname

    # Nota: Correr como root el siguiente comando en cada una de las estaciones:
    # /sbin/changehostname cic01
}

function nfs {

    sudo apt-get install nfs-common

    if [ -z "`cat /etc/fstab | grep nilo`" ]; then
        echo "Adding fstab line..."
        sudo sh -c 'echo "nilo.ic-itcr.ac.cr:/storage/home    /home           nfs     defaults,_netdev,auto 0 0" >> /etc/fstab'
    else
        echo "Ignoring insertion of fstab line."
    fi
}

function ldap {

    # Instalación de paquetes para autenticar vía LDAP
    #  (Responder que se desea mantener la versión instalada)
    $INSTALL ./conf/etc/ldap/ldap.conf /etc/ldap/ldap.conf
    sudo apt-get install libpam-ldapd

    # Instalación de archivos de configuración
    sudo cp /etc/nslcd.conf /etc/nslcd.conf.original
    sudo install --owner=root --group=nslcd --mode=640 ./conf/etc/nslcd.conf /etc/nslcd.conf

    sudo cp /etc/nsswitch.conf /etc/nsswitch.conf.original
    $INSTALL ./conf/etc/nsswitch.conf /etc/nsswitch.conf

}

function users {

    # Crea home para usuarios locales
    sudo mkdir -p /local/home/

    # Crear usuarios locales/invitado
    if [ -z  "`cat /etc/passwd | grep curso`" ]; then
        echo "Adding users..."
        sudo useradd --create-home --home /local/home/curso/ --skel /etc/skel/ --shell /bin/bash --password $(perl -e 'print crypt("curso", "blacksheep")') curso
    else
        echo "Ignoring the addition of local users"
    fi

    # Mover el home del administrador a la carpeta de homes locales
    # Ejecutar los siguientes comandos como root:
    #sudo mkdir -p /local/home/administrator
    #sudo cp /etc/skel/* /local/home/administrator
    #sudo cp /etc/skel/.* /local/home/administrator
    #sudo chown -R administrator:administrator /local/home/administrator
    #sudo usermod -d /local/home/administrator administrator
}


function help {

    # Imprime la lista de funciones disponibles
    cat $0 | grep "function " | sed 's/ {//' | sed 's/function //'  #Ignore this
}


##########################
# Arguments handling     #
##########################

case "$1" in
check)
    # Verifica la disponibilidad de los paquetes
    repos
    ./package_builder.py check
;;

config)
    # Configura la estación
    nfs
    ldap
    users
    hostname
;;

manual)
    echo "WARNING this mode can perform unsafe actions."

    # Manually insert the name of the function_ or execute it.
    if [ "$2" == "" ]; then
        echo "Insert the name of a function: (CTRL-C to exit)"
        echo "Type \"help\" for a list of available functions."
        read
        $REPLY
        echo "[DONE]"
    else
        $2
        echo "[DONE]"
    fi
;;

*)
    echo "Usage: `basename $0` [check|install|config|manual]"
    exit 1
;;

esac
