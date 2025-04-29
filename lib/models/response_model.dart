import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ResponseModel {
  final String id;
  final String portfolioId;
  final String organizerId;
  final String clientId;
  final String clientName;
  final String eventName;
  final String eventType;
  final DateTime eventDate;
  final double budget;
  final String primaryColor;
  final String secondaryColor;
  final bool needsPhotographer;
  final String clientResponse;
  final String additionalNotes;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;

  ResponseModel({
    required this.id,
    required this.portfolioId,
    required this.organizerId,
    required this.clientId,
    required this.clientName,
    required this.eventName,
    required this.eventType,
    required this.eventDate,
    required this.budget,
    required this.primaryColor,
    required this.secondaryColor,
    required this.needsPhotographer,
    this.clientResponse = '',
    required this.additionalNotes,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'portfolioId': portfolioId,
      'organizerId': organizerId,
      'clientId': clientId,
      'clientName': clientName,
      'eventName': eventName,
      'eventType': eventType,
      'eventDate': eventDate.toIso8601String(),
      'budget': budget,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'needsPhotographer': needsPhotographer,
      'clientResponse': clientResponse,
      'additionalNotes': additionalNotes,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ResponseModel.fromMap(Map<String, dynamic> map) {
    return ResponseModel(
      id: map['id'] ?? '',
      portfolioId: map['portfolioId'] ?? '',
      organizerId: map['organizerId'] ?? '',
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'] ?? '',
      eventName: map['eventName'] ?? '',
      eventType: map['eventType'] ?? '',
      eventDate: DateTime.parse(
        map['eventDate'] ?? DateTime.now().toIso8601String(),
      ),
      budget: map['budget']?.toDouble() ?? 0.0,
      primaryColor: map['primaryColor'] ?? '',
      secondaryColor: map['secondaryColor'] ?? '',
      needsPhotographer: map['needsPhotographer'] ?? false,
      clientResponse: map['clientResponse'] ?? '',
      additionalNotes: map['additionalNotes'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
