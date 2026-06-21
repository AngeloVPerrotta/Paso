#!/bin/bash
# Issues de Paso — correr con: bash crear_issues.sh (en Git Bash)

# ===== BUGS DEL JUEGO =====
gh issue create --title "Niveles avanzados no avanzan ni muestran código al ganar" --label "area:juego,tipo:bug,prioridad:alta" --body "**Anotado:** En los primeros niveles se comporta bien: finalizás, te muestra el código y avanza de nivel. En el resto no — finalizás pero no pasa nada, ni muestra el código ni avanza.

**Desarrollo / ideas:** Bloqueante para la beta. Probable causa: el flujo de victoria (banner → código → siguiente) quizás depende de una condición que solo se cumple en los primeros niveles (el gate de las 3 primeras veces del código-al-ganar, o el track C# de 17 niveles vs C de 12). Revisar que 'pasar de nivel' NO dependa de mostrar el código. Reproducir en un nivel alto de cada track."

gh issue create --title "Tutorial nivel 1: timing del cierre + focus en la consigna" --label "area:juego,tipo:bug" --body "**Anotado:** El tutorial se hace en el mismo nivel 1, no se hace focus en la CONSIGNA al terminar. Al terminar muestra muy rápido lo que pasa y de una tira '¿viste el viaje?'. No se saca la sombra de Probar mientras corre. Ideal: que DEJE de correr, se vea qué pasó, ahí el mensaje '¿viste el viaje?', que se pueda repetir, y al terminar focus en la consigna.

**Desarrollo / ideas:** El timing ya se intentó y quedó a medias. Sumar: (1) al terminar, frenar y quitar el estado 'corriendo' del botón; (2) botón 'ver de nuevo' en el mensaje; (3) spotlight/pulso sobre la consigna al cerrar. Evaluar separar el tutorial a un 'nivel 0' dedicado."

gh issue create --title "Bug visual: cuadrado desfasado (1)" --label "area:juego,tipo:bug" --body "**Anotado:** Cuadrado desfasado. Captura: shots/bug_visual1.png

**Desarrollo / ideas:** Adjuntar la captura arrastrándola al Issue en la web. Revisar si es una celda de estado (mano/memoria) que no se reposiciona al cambiar de resolución o al animar."

gh issue create --title "Bug visual: cuadrado desfasado (2)" --label "area:juego,tipo:bug" --body "**Anotado:** Otro cuadrado desfasado. Captura: shots/bug_visual2.png

**Desarrollo / ideas:** Adjuntar captura. Ver si comparte origen con bug_visual1."

# ===== LANDING =====
gh issue create --title "Script de deploy automático (rebuild web + commit + export .exe)" --label "area:landing,tipo:mejora" --body "**Anotado:** ¿Forma de que el .exe se actualice automáticamente? Da paja exportar todo el tiempo. Idea: un mini script que tire rebuild de la web, commit, y export del .exe.

**Desarrollo / ideas:** Un script (.sh o .ps1) que encadene: export del .exe por Godot headless (--export-release), npm run build de la landing, copia del dist, y opcionalmente commit. El export de Godot por CLI: godot --headless --export-release \"Windows Desktop\" ruta/paso.exe. Cuidado: el .exe pesa, no versionarlo."

gh issue create --title "Agregar logo/ícono al .exe descargable" --label "area:landing,tipo:mejora" --body "**Anotado:** Pendiente: agregar LOGO/ICON al .exe que se descarga.

**Desarrollo / ideas:** Generar .ico del robot (desde el SVG de Robot.astro → PNG 256x256 → .ico multi-tamaño), configurarlo en Godot preset Windows Desktop campo Application/Icon, re-exportar. NO confundir con el aviso de SmartScreen (eso es firma, no ícono)."

gh issue create --title "Sacar 'Jugar en el navegador', dejar solo descarga" --label "area:landing,tipo:futuro" --body "**Anotado:** Sacar la versión de 'Jugar en el navegador', dejar únicamente 'Descargar para Windows'.

**Desarrollo / ideas:** OJO — el modo navegador es cero fricción y es lo que hace que la beta se pruebe. El .exe tiene fricción (descargar + SmartScreen + ejecutar). Recomendación fuerte: NO tocar hasta después de la beta; decidir con datos de cuánta gente usó cada opción."

gh issue create --title "Sacar el robot del logo, dejar solo 'Paso'" --label "area:landing,tipo:mejora" --body "**Anotado:** En la landing, sacar el robot del logo de arriba a la izquierda, dejar solo 'Paso'."

gh issue create --title "Manual de marca de Paso (fuentes, colores, íconos)" --label "area:landing,tipo:mejora" --body "**Anotado:** Estaría bueno un manual de marca: fuentes, colores, íconos, etc.

**Desarrollo / ideas:** Documentar la paleta (arena #F5F2EA, texto #232220, teal #1C7C74, ámbar #E3A23A, verde #6BA368), tipografías (Fraunces/Inter/JetBrains Mono), el robot y sus variantes, el logo. Puede vivir como un BRAND.md o una página de la landing. Sirve para mantener coherencia y para mostrar profesionalismo."

gh issue create --title "Ajuste de wording en el hero" --label "area:landing,tipo:mejora" --body "**Anotado:** Reemplazar 'Aprendés a pensar como un programa —sin escribir código— y después lo ves en C y C# de verdad.' por 'Aprendés a pensar un programa —sin escribir código— y después lo ves en C y C# de verdad.'"

gh issue create --title "Más secciones animadas en la landing (estilo la de Git)" --label "area:landing,tipo:futuro" --body "**Anotado:** Agregar más partes como la que hicimos con Claude Design (la de Git). Está muy dinámica y buena.

**Desarrollo / ideas:** Candidatas a animar: la pantalla del juego (mano/memoria/colas en movimiento), el flujo entrada→robot→salida. Mismo enfoque: Claude Design genera el componente, se integra en Astro. Hacer de a una."

# ===== REPO =====
gh issue create --title "README en español al final" --label "area:repo,tipo:mejora" --body "**Anotado:** Me gusta que el juego sea open source, pero quiero que el README salga en español al final."

gh issue create --title "Evitar que se publiquen los .md internos de instrucciones a Claude" --label "area:repo,tipo:mejora" --body "**Anotado:** Evitar que salgan los .md internos usados para instruir a Claude (ej. CLAUDE.md).

**Desarrollo / ideas:** Agregarlos al .gitignore. Si ya están trackeados, git rm --cached para sacarlos del repo sin borrarlos del disco."

gh issue create --title "Limpiar archivos que floodean el repo" --label "area:repo,tipo:mejora" --body "**Anotado:** Evitar archivos que floodean el repo; dejar módulos más necesarios. Algunos se usaron y ya no sirven — agregarlos al ignore.

**Desarrollo / ideas:** Candidatos: scripts throwaway de captura, reglas CSS muertas en global.css (.git/.gpanel/.gterm de la sección Git vieja), assets de Design System sueltos. Auditar qué archivos no se referencian y limpiarlos."

gh issue create --title "Documentación compacta del proyecto (más que el README)" --label "area:repo,tipo:mejora" --body "**Anotado:** Por buenas prácticas, me gustaría documentación o tener las cosas más compactas en algún lado más que en un README.

**Desarrollo / ideas:** Un docs/ con: arquitectura (qué hace cada .gd y la regla de no tocar lógica), cómo correr/buildear/exportar, el flujo de deploy, y el roadmap. Puede ser markdown simple o algo tipo MkDocs si querés algo más lindo."

# ===== SEGURIDAD =====
gh issue create --title "Aviso 'Windows protegió su PC' al abrir el .exe" --label "area:juego,tipo:futuro" --body "**Anotado:** Al ejecutar el .exe sale 'Windows protegió su PC'. ¿Forma de evitarlo sin tocar la jugabilidad?

**Desarrollo / ideas:** NO se arregla con código. Es porque el .exe no está firmado digitalmente. Opciones: certificado de code-signing (pago, ~100-400 USD/año) o programas de firma para open source (ej. SignPath). Por ahora, asumirlo: quien lo baje le da 'Más información → Ejecutar de todas formas'. Es normal en software indie."

gh issue create --title "Revisión general de ciberseguridad del juego" --label "area:juego,tipo:futuro" --body "**Anotado:** ¿Revisión general de ciberseguridad con Claude? Verificar que no haya huecos que permitan vulnerar el juego.

**Desarrollo / ideas:** Superficie de ataque baja (juego cliente, sin backend con datos sensibles). Revisar: el sandbox de Git (que no ejecute comandos reales del sistema), el save local (.cfg, que no se pueda inyectar), y la build web (que no exponga nada). Tarea acotada, no urgente."

# ===== FEATURES / FUTURO =====
gh issue create --title "Sistema de medallas / certificaciones" --label "area:juego,tipo:futuro" --body "**Anotado:** Sistema de medallas/certificaciones. En beta: insignia 'Medalla BETA TESTER' al terminar el betatest. En producción: medalla 'Completaste el desafío PASO' (no certificación, una medallita) que certifique completar el desafío de C/C#/Git. Inspirado en la insignia de OPI 2.0 de Franco Piso.

**Desarrollo / ideas:** La de BETA TESTER se puede dar al completar el form de feedback o al terminar todos los niveles en esta etapa. Diseñar la medalla con la estética de Paso (Claude Design). Pensar si es solo visual en el juego o algo compartible (imagen descargable para LinkedIn)."

gh issue create --title "Video demo de Paso" --label "area:landing,tipo:futuro" --body "**Anotado:** ¿Hacer un video demo? Sumaría para el repo, LinkedIn, la web inicial, etc.

**Desarrollo / ideas:** Un demo corto (30-60s): pantalla de inicio → armar un programa → robot ejecutando → código C/C# → modulo Git. Sirve para el README (gif/video), el hero de la landing, y un post de LinkedIn. Grabar con OBS, editar simple."

gh issue create --title "Humor: referencias de programación (bugs, etc.)" --label "area:juego,tipo:futuro" --body "**Anotado:** (Research while true: learn) Incluir referencias a cosas de programación, ej. bugs, mini cosas graciosas pero no demasiado IA.

**Desarrollo / ideas:** Ya hay un pool de comentarios secos del robot al ganar. Esto puede ampliarlo o sumar guiños visuales sutiles. Mantener el tono seco, nada forzado."

gh issue create --title "Canvas de nodos estilo n8n (Paso 2)" --label "area:juego,tipo:futuro" --body "**Anotado:** (Research while true: learn) Un canvas tipo n8n/Freepik para conectar cosas con diagramas, conectar código o partes de un programa. Rompecabezas de código. Tiene un toque de análisis y diseño de sistemas.

**Desarrollo / ideas:** OJO — esto NO es una sección de Paso, es un juego distinto (paradigma flujo/grafo vs secuencia). Otro motor, otro intérprete, otra validación. Agendado como 'Paso 2' o prototipo aparte. No mezclar con el juego actual. Arrancar solo cuando el juego actual esté cerrado y con feedback."