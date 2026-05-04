# Guia Generica de Pruebas de Infraestructura

Este documento explica como probar la infraestructura directamente en AWS.

La idea es que cualquier equipo pueda clonar el repo y ejecutar los mismos pasos.

## 1. Requisitos minimos

Instala lo siguiente en el equipo:

- Git
- Terraform (version recomendada: 1.6 o superior)
- AWS CLI v2

Verifica versiones:

```bash
git --version
terraform version
aws --version
```

## 2. Clonar y entrar al proyecto

```bash
git clone <URL_DEL_REPO>
cd Proyecto-Final-Cloud-Computing
```

## 3. Despliegue directo en AWS

> Importante: evita usar root para trabajo diario. Usa un usuario IAM con permisos suficientes para la maqueta.

### 3.1 Configurar credenciales AWS CLI

```bash
aws configure
```

Valores sugeridos:

- AWS Access Key ID: tu access key
- AWS Secret Access Key: tu secret key
- Default region name: us-east-1
- Default output format: json

Verifica identidad:

```bash
aws sts get-caller-identity
```

### 3.2 Preparar variables de Terraform

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` y confirma:

- region, CIDRs y tags segun tu entorno
- nombres de recursos segun convencion del equipo

### 3.3 Inicializar y validar Terraform

```bash
terraform init
terraform fmt -recursive
terraform validate
```

### 3.4 Plan de cambios en AWS

```bash
terraform plan -var-file=terraform.tfvars
```

### 3.5 Crear recursos en AWS

```bash
terraform apply -var-file=terraform.tfvars
```

### 3.6 Verificar recursos creados

```bash
terraform output
terraform state list
```

### 3.7 Eliminar recursos en AWS (limpieza)

```bash
terraform destroy -var-file=terraform.tfvars
```

## 4. Flujo recomendado de trabajo

1. Guardar cambios en Terraform antes de hacer `apply`.
2. Revisar el `plan` antes de aplicar.
3. Al terminar pruebas, ejecutar `destroy` para evitar costos.

## 5. Problemas comunes

### Error: No valid credential sources found

No hay credenciales AWS cargadas.

Solucion:

```bash
aws configure
aws sts get-caller-identity
```

### Error: Rate exceeded en IAM

La cuenta esta limitada o se hicieron demasiadas operaciones en poco tiempo.

Solucion:

- Esperar 1-2 minutos y reintentar.
- Reducir operaciones masivas.
- Usar politicas por grupo en vez de adjuntar muchas politicas a un usuario.

### Error: Cannot exceed quota for PoliciesPerUser: 10

El usuario IAM tiene demasiadas politicas adjuntas.

Solucion:

- Mover permisos a un grupo IAM.
- Usar una politica personalizada unificada.
- Evitar adjuntar multiples politicas redundantes al usuario.

### Terraform no encontrado

Si instalaste Terraform en ruta local:

```bash
~/.local/bin/terraform version
```

Usa `~/.local/bin/terraform` en los comandos o agrega esa ruta a tu PATH.

## 6. Checklist rapido

Antes de `apply`:

- `terraform validate` sin errores
- `terraform plan` revisado
- archivo `.tfvars` correcto para el entorno
- credenciales AWS configuradas correctamente

Despues de pruebas:

- `terraform destroy` ejecutado
- cambios documentados en el commit
