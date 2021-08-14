variable "project_name" {
    default = "droneapp"
}

variable "description" {
    default = "Drone App"
}

variable "visibility" {
    default = "private"
    #Options private, public
}

variable "version_control" {
    default = "Git"
    #Options Git, Tfvc
}

variable "work_item_template" {
    default = "Agile"
    #Options Agile, Basic, CMMI, Scrum
}

variable "MYREPO" {
    # Pass from TF_VAR_MYREPO
}
