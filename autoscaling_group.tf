resource "aws_autoscaling_policy" "scale_down_single" {
  name                   = "elasticsearch-scale_downsingle"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = "${aws_autoscaling_group.elasticsearch.name}"
}

resource "aws_cloudwatch_metric_alarm" "scale_down" {
  alarm_description   = "Monitors CPU utilization for ElasticSearch Cluster Nodes"
  alarm_actions       = ["${aws_autoscaling_policy.scale_down_single.arn}"]
  alarm_name          = "elasticsearch-scale_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = "${var.elasticsearch_scale_down_cpu_threshold}"
  evaluation_periods  = "2"
  period              = "${var.elasticsearch_scale_down_period}"
  statistic           = "Average"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.elasticsearch.name}"
  }
}

resource "aws_autoscaling_policy" "scale_up_single" {
  name                   = "elasticsearch-scale_up_single"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = "${aws_autoscaling_group.elasticsearch.name}"
}

resource "aws_cloudwatch_metric_alarm" "scale_up" {
  alarm_description   = "Monitors CPU utilization for ElasticSearch Cluster Nodes"
  alarm_actions       = ["${aws_autoscaling_policy.scale_up_single.arn}"]
  alarm_name          = "elasticsearch-scale_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = "${var.elasticsearch_scale_up_cpu_threshold}"
  evaluation_periods  = "2"
  period              = "${var.elasticsearch_scale_up_period}"
  statistic           = "Average"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.elasticsearch.name}"
  }
}
resource "aws_autoscaling_group" "elasticsearch" {
  name                 = "${var.service_name}-${var.environment}-elasticsearch"
  max_size             = "${var.elasticsearch_max_instances}"
  min_size             = "${var.elasticsearch_min_instances}"
  desired_capacity     = "${var.elasticsearch_desired_instances}"
  default_cooldown     = 30
  force_delete         = true

  health_check_type = "ELB"
  health_check_grace_period = "${var.elasticsearch_health_check_grace_period}"

  launch_template      = {
    id      = "${aws_launch_template.elasticsearch.id}"
    version = "$$Latest"
  }

  vpc_zone_identifier  = ["${data.aws_subnet_ids.all_subnets.ids}"]
  load_balancers       = ["${aws_elb.elasticsearch_elb.*.id}"]

  warm_pool {
    pool_state                  = "Stopped"
    min_size                    = 1
    # The default value of max_group_prepared_capacity is used which
    # keeps the pool sized to match the difference between the ASG's
    # max capacity and its desired capacity.
    # https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-warm-pools.html#create-a-warm-pool-console

    instance_reuse_policy {
      reuse_on_scale_in = true
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.service_name}-${var.environment}-elasticsearch"
    propagate_at_launch = true
  }

  tag {
    key                 = "team"
    value               = "${var.service_name}"
    propagate_at_launch = true
  }

  tag {
    key   = "env"
    value = "${var.environment}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = ["desired_capacity"]
  }
}
