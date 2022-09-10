%lang starknet
# from contracts.constants.perpx_constants import MAX_PRICE, MAX_AMOUNT, MAX_LIQUIDITY

func setup_helpers():
    %{
        import random

        def print_hello():
            print('hello from random function')

        context.random_function = print_hello

        def get_random_values(max_price, max_amount, max_liquidity, seed):
            random.seed(seed)
            price = random.randint(0,max_price)
            amount = random.randint(0,max_amount)
            long = random.randint(0,max_price*max_amount)
            short = random.randint(0,max_price*max_amount)
            liquidity = random.randint(0,max_liquidity)

            #print('price: ')
            #print(price)
            #print('amount: ')
            #print(amount)
            #print('long: ')
            #print(long)
            #print('short: ')
            #print(short)
            #print('liquidity: ')
            #print(liquidity)

            return (price, amount, long,  short, liquidity)

        context.get_random_values = get_random_values

        def unsigned_int(value):
            prime = 2 ** 251 + 17 * 2 ** 192 + 1
            if value < 0:
                value = prime + value
                #print('negative corrected value is: ')
                #print(value)
            return value

        context.unsigned_int = unsigned_int
    %}
    return ()
end
