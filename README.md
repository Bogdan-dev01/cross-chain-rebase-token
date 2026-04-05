1. A protocol that allows user to deposit in vault and it return, receiver rebase tokens that reprecent their underlying balance
2. Rebase token -> balanceOf function is dynamic to show the changing balance with the time.
    - Balance increses linearly by time;
    - Mint tokens to our users every time they preform an action (minting, burning, transferring, or bridging);
3. Interest rate:
    - Individualy set an interest rate or each user based on some global interest rate of the protocol at the time the user deposit into the vault;
    - This global interest rate can only decrease to incetivise/reward early adopters;
    - Increase token addoption;