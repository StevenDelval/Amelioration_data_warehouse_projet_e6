CREATE SCHEMA security;

CREATE TABLE security.user_seller_mapping (
    database_user SYSNAME PRIMARY KEY,
    seller_id UNIQUEIDENTIFIER
);

CREATE TABLE security.user_seller_mapping (
    database_user SYSNAME PRIMARY KEY,
    seller_id UNIQUEIDENTIFIER
);

INSERT INTO security.user_seller_mapping (database_user, seller_id)
VALUES (
    'seller_powell',
    LOWER('b086ab2e-de36-40f1-8520-a8f93abc4045')
);

CREATE FUNCTION security.fn_rls_seller(@seller_id UNIQUEIDENTIFIER)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS fn_securitypredicate_result
    FROM security.user_seller_mapping
    WHERE database_user = USER_NAME()
      AND seller_id = @seller_id

    UNION ALL

    -- Accès complet pour les membres d'un rôle privilégié
    SELECT 1 AS fn_securitypredicate_result
    WHERE IS_MEMBER('role_data_engineer') = 1
       OR IS_MEMBER('role_system_admin') = 1
       OR IS_MEMBER('role_quality_operator') = 1
       OR IS_MEMBER('role_data_governance') = 1
);

CREATE SECURITY POLICY seller_filter_policy
ADD FILTER PREDICATE security.fn_rls_seller(seller_id)
ON marts.fact_sales
WITH (STATE = ON);


-- Exemple usage
INSERT INTO security.user_seller_mapping (database_user, seller_id)
VALUES (
    'seller_powell',
    LOWER('b086ab2e-de36-40f1-8520-a8f93abc4045'),
);

CREATE USER seller_powell WITH PASSWORD = 'MotDePasseFort!2026';

ALTER ROLE role_read_only
ADD MEMBER seller_powell;