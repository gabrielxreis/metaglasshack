"""Lê o rolo da câmera do iPhone pelo cabo (AFC) e acha o que foi gravado pelos óculos Meta.

Uso:
  rolo_iphone.py scan              -> JSON com os arquivos dos óculos (lê só o cabeçalho de cada arquivo)
  rolo_iphone.py pull <caminho> <destino>
"""
import asyncio, json, sys, time
from pymobiledevice3.lockdown import create_using_usbmux
from pymobiledevice3.services.afc import AfcService

EXT = (".jpg", ".jpeg", ".heic", ".mp4", ".mov")
SINAIS = (b"Ray-Ban", b"RAY-BAN", b"Meta AI", b"Meta Platforms", b"Meta View", b"Oakley", b"stella")


async def cabecalho(afc, caminho, tamanho):
    h = await afc.fopen(caminho)
    try:
        dados = await afc.fread(h, min(256 * 1024, tamanho))
        if caminho.lower().endswith((".mp4", ".mov")) and tamanho > 512 * 1024:
            # metadado de vídeo costuma ficar no fim (moov)
            await afc.fseek(h, max(0, tamanho - 256 * 1024))
            dados += await afc.fread(h, 256 * 1024)
        return dados
    finally:
        await afc.fclose(h)


async def scan():
    lockdown = await create_using_usbmux()
    async with AfcService(lockdown) as afc:
        achados, total = [], 0
        for pasta in sorted(await afc.listdir("/DCIM")):
            if not pasta.endswith("APPLE"):
                continue
            for nome in await afc.listdir(f"/DCIM/{pasta}"):
                if not nome.lower().endswith(EXT):
                    continue
                total += 1
                caminho = f"/DCIM/{pasta}/{nome}"
                st = await afc.stat(caminho)
                tam = int(st.get("st_size", 0))
                dados = await cabecalho(afc, caminho, tam)
                if any(s in dados for s in SINAIS):
                    mt = st.get("st_mtime")
                    achados.append({"path": caminho, "name": nome, "size": tam,
                                    "date": mt.timestamp() if hasattr(mt, "timestamp") else time.time(),
                                    "video": nome.lower().endswith((".mp4", ".mov"))})
                print(json.dumps({"progress": total}), flush=True)
        print(json.dumps({"total": total, "found": achados}), flush=True)


async def pull(caminho, destino):
    lockdown = await create_using_usbmux()
    async with AfcService(lockdown) as afc:
        with open(destino, "wb") as f:
            f.write(await afc.get_file_contents(caminho))


if __name__ == "__main__":
    if sys.argv[1] == "scan":
        asyncio.run(scan())
    else:
        asyncio.run(pull(sys.argv[2], sys.argv[3]))
