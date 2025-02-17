DROP FUNCTION IF EXISTS grest.account_balance (text);

CREATE FUNCTION grest.account_balance (_address text)
    RETURNS json STABLE
    LANGUAGE PLPGSQL
    AS $$
DECLARE
    SA_ID integer DEFAULT NULL;
BEGIN
    IF _address LIKE 'stake%' THEN
        -- Shelley stake address
        RETURN (
            SELECT
                JSON_BUILD_OBJECT('stake_address', STAKE_ADDRESS, 'balance', CASE WHEN REWARDS_T.REWARDS - WITHDRAWALS_T.WITHDRAWALS < 0 THEN
                        COALESCE(UTXO_T.UTXO, 0) + COALESCE(REWARDS_T.REWARDS, 0) - COALESCE(WITHDRAWALS_T.WITHDRAWALS, 0) + COALESCE(RESERVES_T.RESERVES, 0) + COALESCE(TREASURY_T.TREASURY, 0) - (COALESCE(REWARDS_T.REWARDS, 0) - COALESCE(WITHDRAWALS_T.WITHDRAWALS, 0))
                    ELSE
                        COALESCE(UTXO_T.UTXO, 0) + COALESCE(REWARDS_T.REWARDS, 0) - COALESCE(WITHDRAWALS_T.WITHDRAWALS, 0) + COALESCE(RESERVES_T.RESERVES, 0) + COALESCE(TREASURY_T.TREASURY, 0)
                    END, 'utxo', COALESCE(UTXO_T.UTXO, 0), 'rewards', COALESCE(REWARDS_T.REWARDS, 0), 'withdrawals', COALESCE(WITHDRAWALS_T.WITHDRAWALS, 0), 'rewards_available', CASE WHEN COALESCE(REWARDS_T.REWARDS, 0) - COALESCE(WITHDRAWALS_T.WITHDRAWALS, 0) <= 0 THEN
                        0
                    ELSE
                        COALESCE(REWARDS_T.REWARDS, 0) - COALESCE(WITHDRAWALS_T.WITHDRAWALS, 0)
                    END, 'reserves', COALESCE(RESERVES_T.RESERVES, 0), 'treasury', COALESCE(TREASURY_T.TREASURY, 0))
            FROM (
                SELECT
                    STAKE_ADDRESS.ID,
                    STAKE_ADDRESS.VIEW AS STAKE_ADDRESS
                FROM
                    STAKE_ADDRESS
                WHERE
                    STAKE_ADDRESS.VIEW = _address) T1
            LEFT JOIN LATERAL (
                SELECT
                    COALESCE(SUM(VALUE), 0) AS UTXO
                FROM
                    TX_OUT
                    LEFT JOIN TX_IN ON TX_OUT.TX_ID = TX_IN.TX_OUT_ID
                        AND TX_OUT.INDEX::smallint = TX_IN.TX_OUT_INDEX::smallint
                WHERE
                    TX_OUT.STAKE_ADDRESS_ID = T1.ID
                    AND TX_IN.TX_IN_ID IS NULL) UTXO_T ON TRUE
            LEFT JOIN LATERAL (
                SELECT
                    COALESCE(SUM(REWARD.AMOUNT), 0) AS REWARDS
                FROM
                    REWARD
                WHERE
                    REWARD.ADDR_ID = T1.ID
                    AND REWARD.SPENDABLE_EPOCH <= (
                        SELECT
                            MAX(NO)
                        FROM
                            EPOCH)
                    GROUP BY
                        T1.ID) REWARDS_T ON TRUE
                LEFT JOIN LATERAL (
                    SELECT
                        COALESCE(SUM(WITHDRAWAL.AMOUNT), 0) AS WITHDRAWALS
                    FROM
                        WITHDRAWAL
                    WHERE
                        WITHDRAWAL.ADDR_ID = T1.ID
                    GROUP BY
                        T1.ID) WITHDRAWALS_T ON TRUE
                LEFT JOIN LATERAL (
                    SELECT
                        COALESCE(SUM(RESERVE.AMOUNT), 0) AS RESERVES
                    FROM
                        RESERVE
                    WHERE
                        RESERVE.ADDR_ID = T1.ID
                    GROUP BY
                        T1.ID) RESERVES_T ON TRUE
                LEFT JOIN LATERAL (
                    SELECT
                        COALESCE(SUM(TREASURY.AMOUNT), 0) AS TREASURY
                    FROM
                        TREASURY
                    WHERE
                        TREASURY.ADDR_ID = T1.ID
                    GROUP BY
                        T1.ID) TREASURY_T ON TRUE);
    ELSE
        SELECT
            TX_OUT.STAKE_ADDRESS_ID INTO SA_ID
        FROM
            TX_OUT
        WHERE
            ADDRESS = _address;
        IF SA_ID IS NOT NULL THEN
            -- Shelley address with an associated stake key
            RETURN (
                SELECT
                    json_build_object('address', _address, 'stake_address', STAKE_ADDRESS, 'balance', CASE WHEN REWARDS_T.REWARDS - WITHDRAWALS_T.WITHDRAWALS < 0 THEN
                            COALESCE(UTXO_T.UTXO, 0) + COALESCE(REWARDS_T.REWARDS, 0) - COALESCE(WITHDRAWALS_T.WITHDRAWALS, 0) + COALESCE(RESERVES_T.RESERVES, 0) + COALESCE(TREASURY_T.TREASURY, 0) - (REWARDS_T.REWARDS - WITHDRAWALS_T.WITHDRAWALS)
                        ELSE
                            COALESCE(UTXO_T.UTXO, 0) + COALESCE(REWARDS_T.REWARDS, 0) - COALESCE(WITHDRAWALS_T.WITHDRAWALS, 0) + COALESCE(RESERVES_T.RESERVES, 0) + COALESCE(TREASURY_T.TREASURY, 0)
                        END, 'utxo', COALESCE(UTXO_T.UTXO, 0), 'rewards', COALESCE(REWARDS_T.REWARDS, 0), 'withdrawals', COALESCE(WITHDRAWALS_T.WITHDRAWALS, 0), 'rewards_available', CASE WHEN COALESCE(REWARDS_T.REWARDS, 0) - COALESCE(WITHDRAWALS_T.WITHDRAWALS, 0) <= 0 THEN
                            0
                        ELSE
                            COALESCE(REWARDS_T.REWARDS, 0) - COALESCE(WITHDRAWALS_T.WITHDRAWALS, 0)
                        END, 'reserves', COALESCE(RESERVES_T.RESERVES, 0), 'treasury', COALESCE(TREASURY_T.TREASURY, 0))
                FROM (
                    SELECT
                        STAKE_ADDRESS.ID,
                        STAKE_ADDRESS.VIEW AS STAKE_ADDRESS
                    FROM
                        STAKE_ADDRESS
                    WHERE
                        STAKE_ADDRESS.ID = SA_ID) T1
                LEFT JOIN LATERAL (
                    SELECT
                        COALESCE(SUM(VALUE), 0) AS UTXO
                    FROM
                        TX_OUT
                        LEFT JOIN TX_IN ON TX_OUT.TX_ID = TX_IN.TX_OUT_ID
                            AND TX_OUT.INDEX::smallint = TX_IN.TX_OUT_INDEX::smallint
                    WHERE
                        TX_OUT.STAKE_ADDRESS_ID = T1.ID
                        AND TX_IN.TX_IN_ID IS NULL) UTXO_T ON TRUE
                LEFT JOIN LATERAL (
                    SELECT
                        COALESCE(SUM(REWARD.AMOUNT), 0) AS REWARDS
                    FROM
                        REWARD
                    WHERE
                        REWARD.ADDR_ID = T1.ID
                        AND REWARD.SPENDABLE_EPOCH <= (
                            SELECT
                                MAX(NO)
                            FROM
                                EPOCH)
                        GROUP BY
                            T1.ID) REWARDS_T ON TRUE
                    LEFT JOIN LATERAL (
                        SELECT
                            COALESCE(SUM(WITHDRAWAL.AMOUNT), 0) AS WITHDRAWALS
                        FROM
                            WITHDRAWAL
                        WHERE
                            WITHDRAWAL.ADDR_ID = T1.ID
                        GROUP BY
                            T1.ID) WITHDRAWALS_T ON TRUE
                    LEFT JOIN LATERAL (
                        SELECT
                            COALESCE(SUM(RESERVE.AMOUNT), 0) AS RESERVES
                        FROM
                            RESERVE
                        WHERE
                            RESERVE.ADDR_ID = T1.ID
                        GROUP BY
                            T1.ID) RESERVES_T ON TRUE
                    LEFT JOIN LATERAL (
                        SELECT
                            COALESCE(SUM(TREASURY.AMOUNT), 0) AS TREASURY
                        FROM
                            TREASURY
                        WHERE
                            TREASURY.ADDR_ID = T1.ID
                        GROUP BY
                            T1.ID) TREASURY_T ON TRUE);
        ELSE
            --  Shelley address without an associated stake key or Byron address
            RETURN (
                SELECT
                    json_build_object('address', _address, 'balance', UTXO_T.UTXO)
                FROM (
                    SELECT
                        COALESCE(SUM(VALUE), 0) AS UTXO
                    FROM
                        TX_OUT
                    LEFT JOIN TX_IN ON TX_OUT.TX_ID = TX_IN.TX_OUT_ID
                        AND TX_OUT.INDEX::smallint = TX_IN.TX_OUT_INDEX::smallint
                WHERE
                    TX_OUT.ADDRESS = _address
                    AND TX_IN.TX_IN_ID IS NULL) UTXO_T);
        END IF;
    END IF;
END;
$$;

COMMENT ON FUNCTION grest.account_balance IS 'Get the account balance of an address';

