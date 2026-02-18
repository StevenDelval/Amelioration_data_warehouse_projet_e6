CREATE PROCEDURE sp_upsert_dim_customer
    @customer_id VARCHAR(50),
    @name NVARCHAR(255),
    @email NVARCHAR(255),
    @city NVARCHAR(100),
    @country NVARCHAR(100),
    @address NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @current_customer_sk INT;
    DECLARE @today DATE = CAST(GETDATE() AS DATE);

    -- Vérifier s'il existe déjà un enregistrement actuel pour ce customer_id
    SELECT @current_customer_sk = customer_sk
    FROM dim_customer
    WHERE customer_id = @customer_id
      AND is_current = 1;

    -- Si l'enregistrement existe
    IF @current_customer_sk IS NOT NULL
    BEGIN
        -- Vérifier si l'une des valeurs a changé
        IF EXISTS (
            SELECT 1
            FROM dim_customer
            WHERE customer_sk = @current_customer_sk
              AND (name <> @name OR email <> @email OR city <> @city OR country <> @country OR address <> @address)
        )
        BEGIN
            -- Mettre fin à l'enregistrement actuel
            UPDATE dim_customer
            SET end_date = @today,
                is_current = 0
            WHERE customer_sk = @current_customer_sk;

            -- Insérer un nouvel enregistrement avec les nouvelles valeurs
            INSERT INTO dim_customer (customer_id, name, email, city, country, address, start_date, is_current)
            VALUES (@customer_id, @name, @email, @city, @country, @address, @today, 1);
        END
        -- sinon : aucune modification, ne rien faire
    END
    ELSE
    BEGIN
        -- Aucun enregistrement existant : créer un nouvel enregistrement
        INSERT INTO dim_customer (customer_id, name, email, city, country, address, start_date, is_current)
        VALUES (@customer_id, @name, @email, @city, @country, @address, @today, 1);
    END
END;