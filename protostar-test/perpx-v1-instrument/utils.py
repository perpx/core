PRIME = 2**251 + 17 * 2**192 + 1 

def signed_int(value):
    return value if value <= PRIME/2 else -(PRIME - value)