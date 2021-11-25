import boto3
import optparse
import logging
import sys

from botocore.exceptions import ClientError

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("setupDC")


def get_parameters():
    p = optparse.OptionParser()
    p.add_option("--Status", "-S", default="", help="Status of DivvyCloud.")
    p.add_option("--Region", "-R", default="us-east-1", help="Dev DivvyCloud AWS region.")
    p.add_option("--TagValue", "-T", default="DivvyCloud", help="Tag Value of DivvyCloud EC2 instances.")
    p.add_option("--TargetGroup", "-G", default="divvycloud-lb-tg", help="Target Group Name of DC instances.")
    p.add_option("--IAMRole", "-I", default="arn:aws:iam::982267650803:role/CXCloudformationJenkins", help="IAM Role to assume.")
    options, arguments = p.parse_args()
    arguments_dictionary = {
        "Status": str(options.Status),
        "Region": str(options.Region),
        "TagValue": options.TagValue,
        "TargetGroup": options.TargetGroup,
        "IAMRole": options.IAMRole
    }
    return arguments_dictionary


def createSession(region, IAMRole):
    try:
        sts = boto3.client('sts', region)
        credentials = sts.assume_role(
            RoleArn=IAMRole,
            RoleSessionName="Dev-DC",
            DurationSeconds=3600
        )
        session = boto3.session.Session(
            aws_access_key_id=credentials.get('Credentials').get('AccessKeyId'),
            aws_secret_access_key=credentials.get('Credentials').get('SecretAccessKey'),
            aws_session_token=credentials.get('Credentials').get('SessionToken')
        )
        log.info("Session Created")
        return session
    except Exception as e:
        log.error("Cannot initialize_target_session, Reason: " + str(e))
        sys.exit(str(e))


def getDCInstanceIDs(session, TagValue, region):
    try:
        ec2 = session.client('ec2', region)
        ec2s = ec2.describe_instances(
            Filters=[
                {
                    'Name': 'tag:Product',
                    'Values': [TagValue]
                }
            ]
        )
        InstanceIDs = []
        instances = ec2s["Reservations"]
        for instance in instances:
            InstanceIDs.append(instance["Instances"][0]["InstanceId"])
        return InstanceIDs
    except Exception as e:
        log.error("Error in getDCInstanceIDs: " + str(e))
        sys.exit(str(e))


def getDCInstanceStatus(session, InstanceIDs, region):
    try:
        ec2 = session.client('ec2', region)
        ec2s = ec2.describe_instances(InstanceIds=InstanceIDs)
        InstanceStatus = []
        for instance in ec2s["Reservations"]:
            InstanceStatus.append({"InstanceId": instance["Instances"][0]["InstanceId"], "State": instance["Instances"][0]["State"]["Name"]})
        return InstanceStatus
    except Exception as e:
        log.error("Error in getDCInstanceStatus: " + str(e))
        sys.exit(str(e))


def stopDCInstances(session, InstanceStatus, region):
    ec2 = session.client('ec2', region)
    if isDCup(InstanceStatus):
        for instance in InstanceStatus:
            if instance["State"] == "running":
                try:
                    response = ec2.stop_instances(InstanceIds=[instance["InstanceId"]], DryRun=False)
                    log.info("DivvyCloud Instance: " + response["StoppingInstances"][0]["InstanceId"] + " is " + response["StoppingInstances"][0]["CurrentState"]["Name"])
                except ClientError as e:
                    log.error("Error in stopDCInstances: " + str(e))
                    sys.exit(str(e))
            else:
                log.info("DivvyCloud Instance: " + instance["InstanceId"] + " is not running")
        log.info("Waiting for DC instances to be shut down...")
        insList = []
        for instance in InstanceStatus:
            insList.append(instance["InstanceId"])
        waiter = ec2.get_waiter('instance_stopped')
        waiter.wait(InstanceIds=insList)
        ec2Status = getDCInstanceStatus(session, insList, region)
        log.info("\n\n")
        for instance in ec2Status:
            log.info("DivvyCloud Instance " + instance["InstanceId"] + " is " + instance["State"])
    return ""


def startDCInstances(session, InstanceStatus, TargetGroup, region):
    ec2 = session.client('ec2', region)
    if not isDCup(InstanceStatus):
        for instance in InstanceStatus:
            if instance["State"] != "running":
                try:
                    response = ec2.start_instances(InstanceIds=[instance["InstanceId"]], DryRun=False)
                    log.info("DivvyCloud Instance: " + response["StartingInstances"][0]["InstanceId"] + " is " + response["StartingInstances"][0]["CurrentState"]["Name"])
                except ClientError as e:
                    log.error("Error in startDCInstances: " + str(e))
                    sys.exit(str(e))
            else:
                log.info("DivvyCloud Instance: " + instance["InstanceId"] + " is already running")
        insList = []
        log.info("Waiting for DC instances to be healthy...")
        for instance in InstanceStatus:
            insList.append(instance["InstanceId"])
        waiter = ec2.get_waiter('instance_status_ok')
        waiter.wait(InstanceIds=insList)
        ec2Status = getDCInstanceStatus(session, insList, region)
        log.info("\n\n")
        up = False
        tgUp = False
        for instance in ec2Status:
            if instance["State"] == "running":
                up = True
            else:
                up = False
            log.info("DivvyCloud Instance " + instance["InstanceId"] + " is " + instance["State"])
        if up:
            tg = session.client("elbv2")
            tgARN = ""
            target_groups = tg.describe_target_groups(Names=[TargetGroup])
            for target in target_groups["TargetGroups"]:
                tgARN = target["TargetGroupArn"]
            if tgARN != "":
                waiter = tg.get_waiter("target_in_service")
                log.info("Waiting for DC containers to be healthy...")
                waiter.wait(TargetGroupArn=tgARN)
                TargetHealthDescriptions = tg.describe_target_health(TargetGroupArn=tgARN)
                for target in TargetHealthDescriptions["TargetHealthDescriptions"]:
                    if target["TargetHealth"]["State"] == "healthy":
                        tgUp = True
                    else:
                        tgUp = False
                        log.info("Target Group Not Healthy")
                if tgUp:
                    log.info("\n\nDev DivvyCloud can be reached on this URL: https://divvycloud.dev.cnxloyalty.com/login")
            else:
                log.info("Unable to get DC target group")
        else:
            log.info("DC Instances are not starting")

    return ""


def isDCup(InstanceStatus):
    for instance in InstanceStatus:
        if instance["State"] != "running":
            return False
    return True


def main():
    try:
        arguments = get_parameters()
        session = createSession(region=arguments["Region"], IAMRole=arguments["IAMRole"])
        ec2IDList = getDCInstanceIDs(session, arguments["TagValue"], arguments["Region"])
        ec2Status = getDCInstanceStatus(session, ec2IDList, arguments["Region"])
        if arguments["Status"] == "Start-DivvyCloud":
            log.info("Starting DC")
            startDCInstances(session, ec2Status, arguments["TargetGroup"], arguments["Region"])
        else:
            log.info("Shutting Down DC")
            stopDCInstances(session, ec2Status, arguments["Region"])
    except Exception as e:
        log.info("Error in main: " + str(e))
        sys.exit(str(e))
    return ""


if __name__ == "__main__":
    main()
