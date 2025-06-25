




variable "project_name" {
  description = "Nom du projet (utilisé pour nommer les ressources Azure)"
  type        = string
  default     = "wp-iac-demo"
}

variable "location" {
  description = "Région Azure pour déployer les ressources"
  type        = string
  default     = "westeurope"  
}

variable "environment" {
  description = "Environnement de déploiement (dev ou prod)"
  type        = string
  default     = "dev"
}

variable "mysql_admin_user" {
  description = "Admin username for MySQL"
  type        = string
  default     = "wpadmin"
}
variable "mysql_admin_password" {
  description = "Admin password for MySQL"
  type        = string
}

variable "mysql_database_name" {
  description = "Nom de la base de données WordPress"
  type        = string
  default     = "wordpress"
}

variable "acr_name_prefix" {
  description = "Préfixe du nom ACR sans caractères spéciaux"
  type        = string
  default     = "wpiacdemo"
}
