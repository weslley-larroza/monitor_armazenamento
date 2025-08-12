📱 Monitor de Armazenamento
Aplicativo Flutter para monitorar e enviar informações de armazenamento de dispositivos Android para um servidor.
Funciona em segundo plano e envia dados periodicamente, permitindo acompanhar o uso de armazenamento de diversos aparelhos na rede.

🚀 Funcionalidades
📊 Exibe informações detalhadas de armazenamento:

Espaço total (MB)

Espaço livre (MB)

Espaço usado (MB e %)

🔄 Atualização manual ou automática a cada 1 minuto

📡 Envio automático dos dados para uma API REST

⚙️ Execução em background usando flutter_background_service

🆔 Geração de ID único do dispositivo para identificação no servidor

🛠 Tecnologias utilizadas
Flutter (Dart)

device_info_plus — informações do dispositivo

disk_space_update — espaço de armazenamento

shared_preferences — persistência local

uuid — geração de IDs únicos

flutter_background_service — execução em segundo plano

http — comunicação com API

📷 Interface
<p align="center"> <img src="CAMINHO_DA_IMAGEM" width="350"> </p>
📡 Fluxo de funcionamento
Ao abrir o app, o dispositivo gera (ou carrega) um ID único salvo localmente.

O app coleta informações de armazenamento e envia para o servidor configurado.

A cada 1 minuto, o processo é repetido automaticamente, mesmo com o app fechado.

É possível atualizar manualmente via botão de refresh na interface.

⚙️ Como rodar o projeto
bash
Copiar
Editar
# Clonar o repositório
git clone https://github.com/SEU_USUARIO/monitor_armazenamento.git

# Entrar na pasta
cd monitor_armazenamento

# Instalar dependências
flutter pub get

# Rodar no dispositivo
flutter run
📌 Observações
O endpoint da API está configurado no código (http://192.168.110.198:5000/api/storage), sendo necessário alterar para o seu servidor.

O envio dos dados requer que o dispositivo esteja conectado à mesma rede ou tenha acesso ao servidor configurado.