import subprocess
import base64
from cryptography import x509
from cryptography.hazmat.backends import default_backend


def get_expiration(base64encoded):
  der = base64.b64decode(base64encoded)
  cert = x509.load_der_x509_certificate(der, default_backend())
  return cert.not_valid_after

if __name__ == "__main__":
  output = subprocess.check_output("cd /tmp; sudo -u postgres psql -d controller -c \"SELECT name, object->>\'certificate\' as cert FROM appliance WHERE (object->>\'activated\')::boolean;\"", shell=True).decode("utf-8")

  certs = []

  for tuple in output.split("\n"):
    if "|" not in tuple:
      continue

    name = tuple.split("|")[0].strip()
    cert = tuple.split("|")[1].strip()

    if len(cert) > 50:
      certs.append([get_expiration(cert), name])

  print("Expiration Date     => Appliance Name")
  print("-------------------------------------")
  for tuple in sorted(certs):
    print(tuple[0].isoformat() + " => " + tuple[1])
