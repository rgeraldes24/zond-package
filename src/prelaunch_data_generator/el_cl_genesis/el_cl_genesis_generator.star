shared_utils = import_module("../../shared_utils/shared_utils.star")

el_cl_genesis_data = import_module("./el_cl_genesis_data.star")

constants = import_module("../../package_io/constants.star")

GENESIS_VALUES_PATH = "/opt"
GENESIS_VALUES_FILENAME = "values.env"
SHADOWFORK_FILEPATH = "/shadowfork"


def generate_el_cl_genesis_data(
    plan,
    image,
    genesis_generation_config_yml_template,
    genesis_unix_timestamp,
    network_params,
    total_num_validator_keys_to_preregister,
    latest_block,
):
    files = {}
    shadowfork_file = ""
    if latest_block != "":
        files[SHADOWFORK_FILEPATH] = latest_block
        shadowfork_file = SHADOWFORK_FILEPATH + "/latest_block.json"

    template_data = new_env_file_for_el_cl_genesis_data(
        genesis_unix_timestamp,
        total_num_validator_keys_to_preregister,
        shadowfork_file,
        network_params,
    )
    genesis_generation_template = shared_utils.new_template_and_data(
        genesis_generation_config_yml_template, template_data
    )

    genesis_values_and_dest_filepath = {}

    genesis_values_and_dest_filepath[
        GENESIS_VALUES_FILENAME
    ] = genesis_generation_template

    genesis_generation_config_artifact_name = plan.render_templates(
        genesis_values_and_dest_filepath, "genesis-el-cl-env-file"
    )

    files[GENESIS_VALUES_PATH] = genesis_generation_config_artifact_name

    genesis = plan.run_sh(
        name="run-generate-genesis",
        description="Creating genesis",
        run="cp /opt/values.env /config/values.env && ./entrypoint.sh all && mkdir /network-configs && mv /data/metadata/* /network-configs/",
        image=image,
        files=files,
        store=[
            StoreSpec(src="/network-configs/", name="el_cl_genesis_data"),
        ],
        wait=None,
    )

    result = el_cl_genesis_data.new_el_cl_genesis_data(
        genesis.files_artifacts[0],
    )

    return result


def new_env_file_for_el_cl_genesis_data(
    genesis_unix_timestamp,
    total_num_validator_keys_to_preregister,
    shadowfork_file,
    network_params,
):
    return {
        "UnixTimestamp": genesis_unix_timestamp,
        "NetworkId": constants.NETWORK_ID[network_params.network.split("-")[0]]
        if shadowfork_file
        else network_params.network_id,  # This will override the network_id if shadowfork_file is present. If you want to use the network_id, please ensure that you don't use "shadowfork" in the network name.
        "DepositContractAddress": network_params.deposit_contract_address,
        "SecondsPerSlot": network_params.seconds_per_slot,
        "PreregisteredValidatorKeysMnemonic": network_params.preregistered_validator_keys_mnemonic,
        "NumValidatorKeysToPreregister": total_num_validator_keys_to_preregister,
        "GenesisDelay": 0,  # This delay is already precaculated in the final_genesis_timestamp
        "GenesisGasLimit": network_params.genesis_gaslimit,
        "MaxPerEpochActivationChurnLimit": network_params.max_per_epoch_activation_churn_limit,
        "ChurnLimitQuotient": network_params.churn_limit_quotient,
        "EjectionBalance": network_params.ejection_balance,
        "Eth1FollowDistance": network_params.eth1_follow_distance,
        "GenesisForkVersion": constants.GENESIS_FORK_VERSION,
        "ShadowForkFile": shadowfork_file,
        "MinValidatorWithdrawabilityDelay": network_params.min_validator_withdrawability_delay,
        "ShardCommitteePeriod": network_params.shard_committee_period,
        "DataColumnSidecarSubnetCount": network_params.data_column_sidecar_subnet_count,
        "SamplesPerSlot": network_params.samples_per_slot,
        "CustodyRequirement": network_params.custody_requirement,
        "Preset": network_params.preset,
        "AdditionalPreloadedContracts": json.encode(
            network_params.additional_preloaded_contracts
        ),
        "PrefundedAccounts": json.encode(network_params.prefunded_accounts),
        "GossipMaxSize": network_params.gossip_max_size,
    }
