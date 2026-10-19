import socket
import argparse
import atexit
import logging
from pathlib import Path

try:
    import readline
except ImportError:
    readline = None

DATA_WIDTH = 16
MAX_VAL = (1 << DATA_WIDTH) - 1
HEX_PADDING = DATA_WIDTH // 4

HOST = 'localhost'
PORT = 2540
SOCKET_TIMEOUT = 60.0
HISTORY_FILE = Path.home() / ".jtag_fpga_history"

def load_history():
    if readline is not None and hasattr(readline, "read_history_file"):
        try:
            readline.read_history_file(str(HISTORY_FILE))
        except FileNotFoundError:
            pass
        except OSError as exc:
            logging.warning(f"Could not load command history: {exc}")

def save_history():
    if readline is not None and hasattr(readline, "write_history_file"):
        try:
            readline.write_history_file(str(HISTORY_FILE))
        except OSError as exc:
            logging.warning(f"Could not save command history: {exc}")

atexit.register(save_history)

def open_connection(host_addr, server_port):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(SOCKET_TIMEOUT)
        s.connect((host_addr, server_port))
        logging.info(f"Connected to server {host_addr}:{server_port}")
        return s
    except socket.timeout:
        logging.error(f"Connection to {host_addr}:{server_port} timed out.")
        return None
    except ConnectionRefusedError:
        logging.error(f"Connection to {host_addr}:{server_port} refused. Is the TCL server running?")
        return None
    except Exception as e:
        logging.error(f"Could not connect to server: {e}")
        return None

def read_response_line(conn, operation):
    response_bytes = bytearray()
    while True:
        try:
            chunk = conn.recv(1)
        except socket.timeout as exc:
            raise TimeoutError(f"Timed out waiting for the {operation}.") from exc
        if not chunk:
            raise ConnectionError(
                f"Connection closed while waiting for the {operation}."
            )
        if chunk == b'\n':
            return response_bytes.decode().strip()
        response_bytes.extend(chunk)

def write_value_to_fpga(conn, address, int_value_to_write, strict=False):
    if conn is None:
        logging.error("No connection to server. Cannot write.")
        if strict:
            raise ConnectionError("No connection to JTAG server.")
        return
    try:
        ADDR_WIDTH = 32
        bin_addr = format(address, f'0{ADDR_WIDTH}b')
        bin_data = format(int_value_to_write, f'0{DATA_WIDTH}b')
        request = f"WRITE {bin_addr} {bin_data}\n"
        
        logging.debug(f"Python sending write request: {request.strip()}")
        conn.sendall(request.encode())
        response = read_response_line(conn, "write acknowledgment")
        if response != "OK":
            raise RuntimeError(f"JTAG server rejected write: {response}")
    except (socket.timeout, TimeoutError, ConnectionError, RuntimeError) as exc:
        logging.error("Write operation failed: %s", exc)
        if strict:
            raise
    except Exception as exc:
        logging.error(f"Failed to send data: {exc}")
        if strict:
            raise

def read_value_from_fpga(conn, address, strict=False):
    if conn is None:
        logging.error("No connection to server. Cannot read.")
        if strict:
            raise ConnectionError("No connection to JTAG server.")
        return None
    try:
        ADDR_WIDTH = 32
        bin_addr = format(address, f'0{ADDR_WIDTH}b')
        request = f"READ {bin_addr}\n"
        
        logging.debug(f"Python sending read request: {request.strip()}")
        conn.sendall(request.encode())
        response_hex = read_response_line(conn, "read response")
        logging.info(f"Python received raw {DATA_WIDTH}-bit hex response: '{response_hex}'")
        if response_hex.startswith("ERROR "):
            raise RuntimeError(f"JTAG server rejected read: {response_hex[6:]}")
        if not response_hex:
            logging.error("Received empty or incomplete response from server.")
            if strict:
                raise ValueError("Received an empty read response.")
            return None
        try:
            return int(response_hex, 16)
        except ValueError as exc:
            logging.error(f"Could not parse {DATA_WIDTH}-bit hex string '{response_hex}' to integer.")
            if strict:
                raise ValueError("The server returned an invalid hexadecimal value.") from exc
            return None
    except (socket.timeout, TimeoutError, ConnectionError, RuntimeError) as exc:
        logging.error("Read operation failed: %s", exc)
        if strict:
            raise
        return None
    except Exception as exc:
        logging.error(f"Failed to read data: {exc}")
        if strict:
            raise
        return None

def parse_integer_argument(arg_str, arg_name="argument"):
    if arg_str is None:
        return None
    try:
        return int(arg_str, 0) 
    except ValueError:
        logging.error(f"Invalid format for {arg_name}: '{arg_str}'. Must be an integer.")
        return None

def set_verbosity(level_str):
    logger = logging.getLogger()
    if level_str == "quiet":
        logger.setLevel(logging.ERROR)
        logging.error("Verbosity set to QUIET.")
    elif level_str == "normal":
        logger.setLevel(logging.INFO)
        logging.info("Verbosity set to NORMAL.")
    elif level_str == "debug":
        logger.setLevel(logging.DEBUG)
        logging.debug("Verbosity set to DEBUG.")
    else:
        logging.error("Unknown verbosity level. Use 'quiet', 'normal', or 'debug'.")

def main_loop(conn):
    print(f"\nJTAG Command Processor ({DATA_WIDTH}-bit)")
    print("Available commands: write <address> <value>, read <address> <expected>, verbose <quiet|normal|debug>, history, exit")
    print(f"Values should be 0-{MAX_VAL}.")
    if readline is not None:
        print("Use Up/Down arrows for command history.\n")
    else:
        print("Command-line history is unavailable; install pyreadline3 on Windows to enable it.\n")

    try:
        while True:
            user_input = input(f"JTAG-{DATA_WIDTH}bit> ").strip()
            parts = user_input.split()

            if not parts:
                continue

            command = parts[0].lower()

            if command == 'exit':
                break
                
            elif command == 'verbose':
                if len(parts) == 2:
                    set_verbosity(parts[1].lower())
                else:
                    current_level = logging.getLevelName(logging.getLogger().getEffectiveLevel())
                    logging.info(f"Current verbosity: {current_level}. Usage: verbose <quiet|normal|debug>")
                    
            elif command == 'write':
                if len(parts) != 3:
                    logging.error("Usage: write <address> <value>")
                    continue
                    
                address = parse_integer_argument(parts[1], "address")
                value_to_write = parse_integer_argument(parts[2], "value")
                
                if address is None or value_to_write is None:
                    continue
                    
                if not (0 <= value_to_write <= MAX_VAL):
                    logging.error(f"Value to write ({value_to_write}) out of {DATA_WIDTH}-bit range (0-{MAX_VAL}).")
                    continue
                    
                logging.info(f"Executing WRITE: Address=0x{address:X}, Value={value_to_write} (0x{value_to_write:0{HEX_PADDING}x})")
                write_value_to_fpga(conn, address, value_to_write)
            
            elif command == 'read':
                if len(parts) != 3:
                    logging.error("Usage: read <address> <expected_value>")
                    continue
                    
                address = parse_integer_argument(parts[1], "address")
                expected_value = parse_integer_argument(parts[2], "expected_value")
                
                if address is None or expected_value is None:
                    continue
                    
                if not (0 <= expected_value <= MAX_VAL):
                    logging.error(f"Expected value ({expected_value}) out of {DATA_WIDTH}-bit range (0-{MAX_VAL}).")
                    continue
                    
                logging.info(f"Executing READ: Address=0x{address:X}, Expecting=0x{expected_value:0{HEX_PADDING}x}")
                actual_value = read_value_from_fpga(conn, address)
                
                if actual_value is None:
                    logging.error("Failed to get actual value from FPGA.")
                    continue
                    
                logging.info(f"Value actually read from FPGA: {actual_value} (0x{actual_value:0{HEX_PADDING}x})")
                
                if actual_value == expected_value:
                    logging.info("MATCH: Read value matches expected value.")
                else:
                    logging.warning(f"MISMATCH: Expected 0x{expected_value:0{HEX_PADDING}x}, Got 0x{actual_value:0{HEX_PADDING}x}.")
                    
            elif command == 'history':
                if readline is not None and hasattr(readline, "get_current_history_length"):
                    logging.info("Command History:")
                    for i in range(1, readline.get_current_history_length() + 1):
                        item = readline.get_history_item(i)
                        if item:
                           logging.info(f"  {i}: {item}")
                else:
                    logging.info("Readline history not fully available.")
                    
            else:
                logging.error(f"Unknown command: '{command}'. Type 'exit' to quit.")
                
    except KeyboardInterrupt:
        pass
    finally:
        if conn:
            conn.close()
            logging.info("Connection closed.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="JTAG Client for FPGA communication.")
    parser.add_argument(
        "-dw", "--data_width", 
        type=int, 
        default=16, 
        choices=[8, 16, 32, 64],
        help="Specify the data width in bits for JTAG operations (default: 16)."
    )
    parser.add_argument(
        "-q", "--quiet",
        action="store_const", const=logging.ERROR, dest="verbosity",
        help="Set verbosity to quiet (only errors)."
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_const", const=logging.DEBUG, dest="verbosity",
        help="Set verbosity to debug (all messages)."
    )
    parser.set_defaults(verbosity=logging.INFO) 

    args = parser.parse_args()

    DATA_WIDTH = args.data_width
    MAX_VAL = (1 << DATA_WIDTH) - 1
    HEX_PADDING = DATA_WIDTH // 4
    
    logging.basicConfig(level=args.verbosity, format='|%(levelname)s| %(message)s')
    
    logging.info(f"Script configured for {DATA_WIDTH}-bit data width.")

    if readline is not None:
        logging.debug("Attempting to load readline history.")
        load_history()

    conn = open_connection(HOST, PORT)
    if conn is None:
        logging.error("Exiting due to connection failure.")
        exit(1) 
    
    main_loop(conn)