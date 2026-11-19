register_step work \
    --desc "Work tools: tshark, tcpreplay, sshpass, Remmina, FileZilla (opt-in: ./bootstrap.sh work)" \
    --group apps --root --optional --needs prereqs \
    --provides tshark tcpreplay sshpass remmina filezilla

step_work() {
    # Lets the wireshark group capture without root; the default answer under
    # an unattended install is no.
    echo "wireshark-common wireshark-common/install-setuid boolean true" \
        | sudo debconf-set-selections
    log "Installing work tools"
    apt_install tshark tcpreplay sshpass remmina filezilla
    sudo dpkg-reconfigure -f noninteractive wireshark-common
    log "Ensuring $USER is in the wireshark group (applies from the next login)"
    sudo usermod -aG wireshark "$USER"
}
