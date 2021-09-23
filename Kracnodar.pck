GDPC                                                                               <   res://.import/icon.png-487276ed1e3a0c39cad0279d744ee560.stex�N      U      -��`�0��x�5�[   res://Scenes/DictEntry.tscn �      3      e�9���������    res://Scenes/Dictionnaire.tscn  �	      �	      �/g��yi�9&�#   res://Scenes/Main.gd.remap  �^      &       `r�EN������po   res://Scenes/Main.gdc   �      V      q�S��`�e[΂Y*,�   res://Scenes/Main.tscn  �      �      ^��F��agXe��v�   res://Scenes/WordButton.tscn�      �      ? �|��T�qN����$    res://Scenes/WordGenerator.tscn 0      �      x��=���iv�i�ӗ)   res://Scenes/WordLinker.tscn�(      j      uP�4P;��B^�!C-    res://Scenes/WordSelector.tscn  `-      �       ���.I���H_�   res://Scripts/Dict.gd.remap �^      '       ���Q9`S����%�@   res://Scripts/Dict.gdc  `2      ^       ����u��0�a�`�G$   res://Scripts/Dictionnaire.gd.remap �^      /       .�b�����p�&��    res://Scripts/Dictionnaire.gdc  �2      I      �o�}�m�|�Zڃ�IX$   res://Scripts/VBoxContainer.gd.remap _      0       7:O}�U�+v�*    res://Scripts/VBoxContainer.gdc 9      �       D6�u���BO�sd���$   res://Scripts/WordButton.gd.remap   P_      -       x
Y�NQH�TEK��-   res://Scripts/WordButton.gdc�9      �       S�c���K�= �p$   res://Scripts/WordGenerator.gd.remap�_      0       ����֣ZKI��T)�    res://Scripts/WordGenerator.gdc �:            -�<�y5������Kv�$   res://Scripts/WordLinker.gd.remap   �_      -       �4���tƩf갶)��   res://Scripts/WordLinker.gdc I      �      ؏Q�{Q������D�s$   res://Scripts/WordSelector.gd.remap �_      /       ߼#�9F��uLn�@�u    res://Scripts/WordSelector.gdc  �J             -���� ����\%   res://default_env.tres   N      �       um�`�N��<*ỳ�8   res://icon.png  `      �      G1?��z�c��vN��   res://icon.png.import   \      �      �����%��(#AB�   res://project.binary m      s      ��~^������:��HK�    [gd_scene format=2]

[node name="Control" type="Control"]
anchor_right = 0.312
anchor_bottom = 0.04
margin_right = 0.511993
margin_bottom = -1.90735e-06
rect_min_size = Vector2( 320, 24 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="WordEntry" type="RichTextLabel" parent="."]
anchor_right = 0.475
anchor_bottom = 1.0
text = "test"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="WordTranslation" type="RichTextLabel" parent="."]
anchor_left = 0.5
anchor_right = 1.0
anchor_bottom = 1.0
text = "test"
__meta__ = {
"_edit_use_anchors_": false
}
             [gd_scene load_steps=2 format=2]

[ext_resource path="res://Scripts/Dictionnaire.gd" type="Script" id=1]

[node name="Dictionnaire" type="Control"]
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource( 1 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="ScrollContainer" type="ScrollContainer" parent="."]
anchor_left = 0.062
anchor_top = 0.107
anchor_right = 0.937
anchor_bottom = 0.84
margin_left = 0.511997
margin_top = -0.199997
margin_right = 0.512024
margin_bottom = -3.05176e-05
__meta__ = {
"_edit_use_anchors_": false
}

[node name="VBoxContainer" type="VBoxContainer" parent="ScrollContainer"]
custom_constants/separation = 0

[node name="SaveButton" type="Button" parent="."]
anchor_left = 0.5
anchor_top = 0.9
anchor_right = 0.5
anchor_bottom = 0.9
margin_left = -208.0
margin_top = -20.0
margin_right = -16.0
margin_bottom = 20.0
text = "Sauvegarder!"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="ImportButton" type="Button" parent="."]
anchor_left = 0.5
anchor_top = 0.9
anchor_right = 0.5
anchor_bottom = 0.9
margin_left = 16.0
margin_top = -20.0
margin_right = 208.0
margin_bottom = 20.0
text = "Importer!"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="SaveDialog" type="FileDialog" parent="."]
visible = true
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -288.0
margin_top = -192.0
margin_right = 288.0
margin_bottom = 192.0
access = 2
current_dir = "/Users/xavie/Documents/Godot/Kracnodar"
current_path = "/Users/xavie/Documents/Godot/Kracnodar/"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="ImportDialog" type="FileDialog" parent="."]
visible = true
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
margin_left = -288.0
margin_top = -192.0
margin_right = 288.0
margin_bottom = 192.0
window_title = "Open a File"
mode = 0
access = 2
current_dir = "/Users"
current_file = "Users"
current_path = "/Users/Users"
__meta__ = {
"_edit_use_anchors_": false
}

[connection signal="pressed" from="SaveButton" to="." method="_on_SaveButton_pressed"]
[connection signal="pressed" from="ImportButton" to="." method="_on_ImportButton_pressed"]
[connection signal="dir_selected" from="SaveDialog" to="." method="_on_FileDialog_dir_selected"]
[connection signal="file_selected" from="SaveDialog" to="." method="_on_SaveDialog_file_selected"]
[connection signal="file_selected" from="ImportDialog" to="." method="_on_ImportDialog_file_selected"]
  GDSC            L      ������ڶ   �����϶�   �����������Ķ���   ���������Ķ�   ������������Ķ��   ������¶   �����������Ҷ���   ���¶���   �����������Ķ���   ������������Ķ��    ���������������������������Ҷ���   ��Զ   �����������Ӷ���   ���������¶�   ���¶���   ���¶���   
   wordPicked        onWordPicked                         	                  !      -      .   	   /   
   6      >      J      3YY0�  PQV�  W�  �  �  T�  PRR�  QYY0�  P�  QV�  W�  �  �  T�	  P�  QYYY0�
  P�  QV�  &P�  �  QV�  W�  �  T�  P�  T�  QY`          [gd_scene load_steps=5 format=2]

[ext_resource path="res://Scenes/WordGenerator.tscn" type="PackedScene" id=1]
[ext_resource path="res://Scenes/Main.gd" type="Script" id=2]
[ext_resource path="res://Scenes/WordSelector.tscn" type="PackedScene" id=3]
[ext_resource path="res://Scenes/Dictionnaire.tscn" type="PackedScene" id=4]

[node name="Main" type="Control"]
anchor_right = 1.008
anchor_bottom = 1.0
margin_right = -0.192017
mouse_filter = 2
script = ExtResource( 2 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="TabContainer" type="TabContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
__meta__ = {
"_edit_use_anchors_": false
}

[node name="Generateur" type="Control" parent="TabContainer"]
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = 4.0
margin_top = 32.0
margin_right = -4.0
margin_bottom = -4.0

[node name="WordGenerator" parent="TabContainer/Generateur" instance=ExtResource( 1 )]
margin_left = -4.0
margin_top = -32.0
margin_right = -4.0
margin_bottom = -32.0

[node name="WordSelector" parent="TabContainer/Generateur" instance=ExtResource( 3 )]
anchor_right = 0.7
margin_left = 404.0
margin_top = -8.0
margin_right = 400.0
margin_bottom = 88.0

[node name="Dictionnaire" parent="TabContainer" instance=ExtResource( 4 )]
visible = false
margin_left = 4.0
margin_top = 32.0
margin_right = -4.0
margin_bottom = -4.0

[connection signal="tab_changed" from="TabContainer" to="." method="_on_TabContainer_tab_changed"]
              [gd_scene load_steps=2 format=2]

[ext_resource path="res://Scripts/WordButton.gd" type="Script" id=1]

[node name="WordButton" type="Button"]
anchor_right = 0.094
anchor_bottom = 0.04
margin_right = -0.256004
margin_bottom = -1.90735e-06
script = ExtResource( 1 )
__meta__ = {
"_edit_use_anchors_": false
}

[connection signal="pressed" from="." to="." method="_on_WordButton_pressed"]
             [gd_scene load_steps=2 format=2]

[ext_resource path="res://Scripts/WordGenerator.gd" type="Script" id=1]

[node name="WordGenerator" type="Control"]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
script = ExtResource( 1 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="TextEdit" type="GridContainer" parent="."]
anchor_left = 0.062
anchor_top = 0.173
anchor_right = 0.43
anchor_bottom = 0.853
margin_left = 0.511997
margin_top = 0.199997
margin_right = -0.320007
margin_bottom = 0.199982
columns = 4

[node name="GeneratorButton" type="Button" parent="."]
anchor_left = 0.062
anchor_top = 0.08
anchor_right = 0.164
anchor_bottom = 0.147
margin_left = 0.511997
margin_top = -3.8147e-06
margin_right = 0.0639954
margin_bottom = -0.199997
text = "Générer!"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="NumberOfSyllablesLabel" type="RichTextLabel" parent="."]
anchor_left = 0.187
anchor_top = 0.08
anchor_right = 0.242
anchor_bottom = 0.107
margin_left = 0.511993
margin_top = -3.8147e-06
margin_right = 0.191986
margin_bottom = -0.200005
text = "Syllabes"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="NumberOfSyllablesInput" type="LineEdit" parent="."]
anchor_left = 0.187
anchor_top = 0.107
anchor_right = 0.242
anchor_bottom = 0.147
margin_left = 0.511993
margin_top = -0.200005
margin_right = 2.19199
margin_bottom = -0.199997
text = "1"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="NumberOfWordsLabel" type="RichTextLabel" parent="."]
anchor_left = 0.187
anchor_top = 0.08
anchor_right = 0.242
anchor_bottom = 0.107
margin_left = 72.512
margin_top = -3.8147e-06
margin_right = 72.192
margin_bottom = -0.200005
text = "Mots"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="NumberOfWordsInput" type="LineEdit" parent="."]
anchor_left = 0.187
anchor_top = 0.107
anchor_right = 0.242
anchor_bottom = 0.147
margin_left = 72.512
margin_top = -0.200005
margin_right = 74.192
margin_bottom = -0.199997
text = "1"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="WordStartLabel" type="RichTextLabel" parent="."]
anchor_left = 0.328
anchor_top = 0.08
anchor_right = 0.43
anchor_bottom = 0.107
margin_left = 0.127991
margin_top = -3.8147e-06
margin_right = -0.320007
margin_bottom = -0.200005
text = "Début du mot"
__meta__ = {
"_edit_use_anchors_": false
}

[node name="WordStartDropdown" type="OptionButton" parent="."]
anchor_left = 0.328
anchor_top = 0.107
anchor_right = 0.43
anchor_bottom = 0.147
margin_left = 0.127991
margin_top = -0.200005
margin_right = -0.320007
margin_bottom = -0.199997

[connection signal="pressed" from="GeneratorButton" to="." method="_on_GeneratorButton_pressed"]
[connection signal="text_changed" from="NumberOfSyllablesInput" to="." method="_on_NumberOfSyllablesInput_text_changed"]
[connection signal="text_changed" from="NumberOfWordsInput" to="." method="_on_NumberOfWordsInput_text_changed"]
[connection signal="item_selected" from="WordStartDropdown" to="." method="_on_WordStartDropdown_item_selected"]
   [gd_scene load_steps=2 format=2]

[ext_resource path="res://Scripts/WordLinker.gd" type="Script" id=1]

[node name="WordLinker" type="Control"]
anchor_right = 0.312
anchor_bottom = 0.067
margin_right = 0.511993
margin_bottom = -0.200001
script = ExtResource( 1 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="WordButton" type="LineEdit" parent="."]
anchor_left = 0.025
anchor_top = 0.2
anchor_right = 0.45
anchor_bottom = 0.8

[node name="TranslationText" type="LineEdit" parent="."]
anchor_left = 0.525
anchor_top = 0.2
anchor_right = 0.975
anchor_bottom = 0.8
margin_left = -1.52588e-05
__meta__ = {
"_edit_use_anchors_": false
}

[node name="DeleteButton" type="Button" parent="."]
anchor_left = -0.1
anchor_top = 0.2
anchor_right = -0.037
anchor_bottom = 0.7
margin_right = -0.16
margin_bottom = -1.90735e-06
text = "X"

[connection signal="text_changed" from="WordButton" to="." method="_on_WordButton_text_changed"]
[connection signal="text_changed" from="TranslationText" to="." method="_on_TranslationText_text_changed"]
[connection signal="pressed" from="DeleteButton" to="." method="_on_DeleteButton_pressed"]
      [gd_scene load_steps=3 format=2]

[ext_resource path="res://Scripts/WordSelector.gd" type="Script" id=1]
[ext_resource path="res://Scripts/VBoxContainer.gd" type="Script" id=2]

[node name="WordSelector" type="Control"]
anchor_right = 1.0
anchor_bottom = 1.0
margin_left = 504.0
mouse_filter = 2
script = ExtResource( 1 )
__meta__ = {
"_edit_use_anchors_": false
}

[node name="VBoxContainer" type="VBoxContainer" parent="."]
anchor_left = 0.138
anchor_top = 0.107
anchor_right = 0.75
anchor_bottom = 0.96
margin_left = 0.23999
margin_top = -0.200005
margin_right = -3.05176e-05
custom_constants/separation = 30
script = ExtResource( 2 )

[node name="AddButton" type="Button" parent="."]
anchor_left = 0.169
anchor_top = 0.027
anchor_right = 0.231
anchor_bottom = 0.08
margin_left = 0.119995
margin_top = -0.200001
margin_right = -0.120003
margin_bottom = -3.8147e-06
text = "+"

[node name="AddAllButton" type="Button" parent="."]
anchor_left = 0.4
anchor_top = 0.747
anchor_right = 0.662
anchor_bottom = 0.787
margin_top = -0.200012
margin_right = -0.240021
margin_bottom = -0.200043
text = "Ajouter!"

[connection signal="pressed" from="AddButton" to="." method="_on_Button_pressed"]
[connection signal="pressed" from="AddAllButton" to="." method="_on_AddAllButton_pressed"]
  GDSC                   ���Ӷ���   ���¶���                   	      3YY;�  NOY`  GDSC   (      $   �      ������ڶ   �������Ӷ���   ������������Ӷ��   �������¶���   ���¶���   ��������϶��   ���Ŷ���   �����������϶���   �������Ӷ���   �������Ӷ���   �������¶���   ��������������Ķ   ������������Ķ��   ��������Ҷ��   ���������¶�   ����Ҷ��   �����������ض���   �����������Ҷ���   ���������Ӷ�   ���������������������Ҷ�   ���������Ѷ�   ����ƶ��   �����������������������Ҷ���   �����������Ѷ���    �����������������������������Ҷ�   ���޶���   ������Ӷ   ���Ӷ���   ����   ���ض���   ���򶶶�   ���ض���   ��������   ����Ӷ��   ����������¶   �����¶�    ���������������������������Ҷ���   ����󶶶   ���¶���   �����������Ѷ���      res://Scenes/DictEntry.tscn    	   WordEntry         WordTranslation                                                   )   	   5   
   D      N      O      V      c      m      s      x      y            �      �      �      �      �      �      �      �      �      �      �      �       �   !   �   "   �   #   �   $   3YB�  YY;�  �L  PQYY0�  P�  QV�  )�  �  T�  PQV�  ;�  �  T�  PQ�  �  T�	  P�  QT�
  P�  Q�  �  T�	  P�  QT�
  P�  L�  MQ�  W�  �  T�  P�  QYY0�  P�  QV�  )�  W�  �  T�  PQV�  W�  �  T�  P�  Q�  �  T�  PQ�  �  P�  QYY0�  PQV�  W�  T�  PQYY0�  PQV�  W�  T�  PQYY0�  P�  QV�  ;�  �  T�  PQ�  �  T�  P�  R�  T�  Q�  ;�  �   T�!  P�  T�"  PQQT�#  �  �  P�  QYY0�$  P�  QV�  ;�  �  T�  PQ�  �  T�  P�  R�  T�%  Q�  ;�  �   T�?  P�&  T�  Q�  �  T�'  P�  QY`       GDSC                   ������������Ķ��   �����϶�                                                 	   	   
   
                                             3YYYYYYYYY0�  PQV�  -YYYYYY` GDSC         	         �����ض�   �����������Ҷ���   ���Ҷ���   ���������������������Ҷ�   ����������ڶ      wordSelected                         	      
                     	   3YYB�  Y;�  YY0�  PQV�  �  PR�  Q�  -Y`    GDSC   2   $   g   J     ������ڶ   ���������Ҷ�   ��������������Ӷ   ��Ѷ   ��������������������Ķ��   ����   ���������Ŷ�   �����Ŷ�   ���������������������Ŷ�   ����ζ��   ����ζ��   ��������������¶   �����������¶���   �����϶�   ������Ӷ   ���۶���   ����������������ض��   �������۶���   �����¶�   ���������������Ӷ���   ������������ζ��   ��������������Ҷ   ���������������������ζ�   ���Ӷ���   �����������������ζ�   ��������ض��   ������Ҷ   ������Ҷ   ������������ζ��   ���������������������¶�   �������¶���   ��������������������������Ҷ   ��������ζ��   �����������������¶�   ��������ض��   �������Ӷ���   �������¶���   ���Ҷ���   ������¶   �������¶���   ��������Ҷ��(   ��������������������������������������Ҷ   ������¶   �����޶�   ������������������ض   �����޶�$   ����������������������������������Ҷ   �����������Ҷ���   ���¶���   ����������ڶ      res://Scenes/WordButton.tscn      w         r         t         p         s         d         f         g         h         j         k         l         z         x         c         v         b         n         m         a         e         i         o         u         Consonne      Voyelle       Any              ^[0-9]*$                         wordSelected      onWordPicked   
   wordPicked                                                      	   "   
   %      (      +      .      1      4      7      :      =      @      C      F      I      L      O      R      U      W      Y      Z      i      j       o   !   r   "   u   #   w   $   y   %   z   &   �   '   �   (   �   )   �   *   �   +   �   ,   �   -   �   .   �   /   �   0   �   1   �   2   �   3   �   4   �   5   �   6   �   7   �   8   �   9   	  :     ;     <   $  =   *  >   +  ?   1  @   6  A   D  B   L  C   R  D   U  E   [  F   j  G   p  H     I   �  J   �  K   �  L   �  M   �  N   �  O   �  P   �  Q   �  R   �  S   �  T   �  U   �  V   �  W   �  X   �  Y   �  Z   �  [     \     ]     ^     _     `   #  a   /  b   1  c   9  d   :  e   A  f   H  g   3YYB�  YY5;�  �L  PQY;�  �  T�  PQYY;�  L�  �  R�  �  R�  �  R�  �  R�  �  R�  �  R�  �  R�  �  R�  �	  R�  �
  R�  �  R�  �  R�  �  R�  �  R�  �  R�  �  R�  �  R�  �  R�  �  YMYY;�  L�  R�  R�  R�  R�  MYY;�  L�  �  R�  �  R�  �  YMYY;�	  �
  T�  PQY;�  �  Y;�  �  YY0�  PQV�  �	  T�  P�  Q�  )�  �  V�  W�  T�  P�  Q�  W�  T�  P�  QYY0�  PQV�  ;�  W�  T�  PQ�  �  T�%  PQ�  ;�  �  T�&  PQ�  T�  PQ�  �  T�%  PQ�  ;�  �  T�&  PQ�  T�  PQ�  ;�  �  �  &P�  �  QV�  �  T�%  PQ�  �  �  T�&  PQ�  �  &P�  �  QV�  .�  L�  M�  L�  M�  &P�  �   QV�  .�  L�  MYY0�  PQV�  ;�  �  �  )�  �  PW�  T�  PQQV�  &P�  �  QV�  �  �  PQ�  (V�  �  T�%  PQ�  ;�  �  T�&  PQ�  T�  PQ�  �  T�%  PQ�  ;�  �  T�&  PQ�  T�  PQ�  �  �  L�  M�  L�  M�  .�  �  Y0�  PQV�  )�   �  PW�!  T�  PQQV�  ;�  �  PQ�  ;�"  �  T�#  PQ�  �"  T�$  P�  Q�  �"  T�%  �  �  �"  T�&  P�!  RR�"  Q�  W�'  T�(  P�"  Q�  Y0�)  P�*  QV�  &�	  T�+  P�*  QV�  W�  T�$  P�*  Q�  �  �*  �  W�  T�,  P�  T�-  PQQ�  .�  W�  T�$  P�  Q�  Y0�.  P�*  QV�  &�	  T�+  P�*  QV�  W�!  T�$  P�*  Q�  �  �*  �  W�!  T�,  P�  T�-  PQQ�  .�  W�!  T�$  P�  Q�  Y0�/  P�0  QV�  �1  P�#  R�0  QY`          GDSC             <      ������ڶ   �������¶���   ��������������¶   �����������������������Ҷ���   ���������Ӷ�   ��������������������������Ҷ   �������¶���$   �������������������������������Ҷ���                   	                                 	      
   %      )      +      ,      -      4      8      :      3YY8;�  V�  Y8;�  V�  YY0�  PQV�  T�  PQYYY0�  P�  QV�  �  �  �  -YYY0�  P�  QV�  �  �  �  -Y`           GDSC            q      ������ڶ   �������������Ӷ�   ������������Ķ��   ���¶���   ������������Ķ��   �������Ӷ���   �������Ӷ���   �������¶���   �������¶���   ������������Ķ��   ��������Ҷ��   �����������������Ҷ�   �����������������������Ҷ���   ����Ҷ��   �����������ض���   ���¶���   ���¶���   ��������������¶      res://Scenes/WordLinker.tscn   
   WordButton                                             (      .   	   6   
   7      8      >      G      O      P      Q      W      b      o      3YY;�  �L  PQYY0�  P�  QV�  ;�  �  T�  PQ�  �  T�  P�  QT�  P�  Q�  �  T�  �  �  W�	  T�
  P�  QYYY0�  PQV�  ;�  �  T�  PQ�  W�	  T�
  P�  QYYY0�  PQV�  )�  W�	  T�  PQV�  �  T�  L�  T�  M�  T�  Y`  [gd_resource type="Environment" load_steps=2 format=2]

[sub_resource type="ProceduralSky" id=1]

[resource]
background_mode = 2
background_sky = SubResource( 1 )
             GDST@   @           9  PNG �PNG

   IHDR   @   @   �iq�   sRGB ���  �IDATx�ݜytTU��?��WK*�=���%�  F����0N��݂:���Q�v��{�[�����E�ӋH���:���B�� YHB*d_*�jyo�(*M�JR!h��S�T��w�߻���ro���� N�\���D�*]��c����z��D�R�[�
5Jg��9E�|JxF׵'�a���Q���BH�~���!����w�A�b
C1�dB�.-�#��ihn�����u��B��1YSB<%�������dA�����C�$+(�����]�BR���Qsu][`
�DV����у�1�G���j�G͕IY! L1�]��� +FS�IY!IP ��|�}��*A��H��R�tQq����D`TW���p\3���M���,�fQ����d��h�m7r�U��f������.��ik�>O�;��xm��'j�u�(o}�����Q�S�-��cBc��d��rI�Ϛ�$I|]�ơ�vJkZ�9>��f����@EuC�~�2�ym�ش��U�\�KAZ4��b�4������;�X婐����@Hg@���o��W�b�x�)����3]j_��V;K����7�u����;o�������;=|��Ŗ}5��0q�$�!?��9�|�5tv�C�sHPTX@t����w�nw��۝�8�=s�p��I}�DZ-̝�ǆ�'�;=����R�PR�ۥu���u��ǻC�sH`��>�p�P ���O3R�������۝�SZ7 �p��o�P!�
��� �l��ހmT�Ƴێ�gA��gm�j����iG���B� ܦ(��cX�}4ۻB��ao��"����� ����G�7���H���æ;,NW?��[��`�r~��w�kl�d4�������YT7�P��5lF�BEc��=<�����?�:]�������G�Μ�{������n�v��%���7�eoݪ��
�QX¬)�JKb����W�[�G ��P$��k�Y:;�����{���a��&�eפ�����O�5,;����yx�b>=fc�* �z��{�fr��7��p���Ôִ�P����t^�]͑�~zs.�3����4��<IG�w�e��e��ih�/ˆ�9�H��f�?����O��.O��;!��]���x�-$E�a1ɜ�u�+7Ȃ�w�md��5���C.��\��X��1?�Nغ/�� ��~��<:k?8��X���!���[���꩓��g��:��E����>��꩓�u��A���	iI4���^v:�^l/;MC��	iI��TM-$�X�;iLH���;iI1�Zm7����P~��G�&g�|BfqV#�M������%��TM��mB�/�)����f����~3m`��������m�Ȉ�Ƽq!cr�pc�8fd���Mۨkl�}P�Л�汻��3p�̤H�>+���1D��i�aۡz�
������Z�Lz|8��.ִQ��v@�1%&���͏�������m���KH�� �p8H�4�9����/*)�aa��g�r�w��F36���(���7�fw����P��&�c����{﹏E7-f�M�).���9��$F�f r �9'1��s2).��G��{���?,�
�G��p�µ�QU�UO�����>��/�g���,�M��5�ʖ�e˃�d����/�M`�=�y=�����f�ӫQU�k'��E�F�+ =΂���
l�&���%%�������F#KY����O7>��;w���l6***B�g)�#W�/�k2�������TJ�'����=!Q@mKYYYdg��$Ib��E�j6�U�,Z�鼌Uvv6YYYԶ��}( ���ߠ#x~�s,X0�����rY��yz�	|r�6l����cN��5ϑ��KBB���5ϡ#xq�7�`=4A�o�xds)�~wO�z�^��m���n�Ds�������e|�0�u��k�ٱ:��RN��w�/!�^�<�ͣ�K1d�F����:�������ˣ����%U�Ą������l{�y����)<�G�y�`}�t��y!��O@� A� Y��sv:K�J��ՎۣQ�܃��T6y�ǯ�Zi
��<�F��1>�	c#�Ǉ��i�L��D�� �u�awe1�e&')�_�Ǝ^V�i߀4�$G�:��r��>h�hݝ������t;)�� &�@zl�Ұր��V6�T�+����0q��L���[t���N&e��Z��ˆ/����(�i啝'i�R�����?:
P].L��S��E�݅�Á�.a6�WjY$F�9P�«����V^7���1Ȓ� �b6�(����0"�k�;�@MC���N�]7 �)Q|s����QfdI���5 ��.f��#1���G���z���>)�N�>�L0T�ۘ5}��Y[�W뿼mj���n���S?�v��ْ|.FE"=�ߑ��q����������p����3�¬8�T�GZ���4ݪ�0�L�Y��jRH��.X�&�v����#�t��7y_#�[�o��V�O����^�����paV�&J�V+V��QY����f+m��(�?/������{�X��:�!:5�G�x���I����HG�%�/�LZ\8/����yLf�Æ>�X�Єǣq���$E������E�Ǣ�����gێ��s�rxO��x孏Q]n���LH����98�i�0==���O$5��o^����>6�a� �*�)?^Ca��yv&���%�5>�n�bŜL:��y�w���/��o�褨A���y,[|=1�VZ�U>,?͑���w��u5d�#�K�b�D�&�:�����l~�S\���[CrTV�$����y��;#�������6�y��3ݸ5��.�V��K���{�,-ւ� k1aB���x���	LL� ����ңl۱������!U��0L�ϴ��O\t$Yi�D�Dm��]|�m���M�3���bT�
�N_����~uiIc��M�DZI���Wgkn����C��!xSv�Pt�F��kڨ��������OKh��L����Z&ip��
ޅ���U�C�[�6��p���;uW8<n'n��nͽQ�
�gԞ�+Z	���{���G�Ĭ� �t�]�p;躆 ��.�ۣ�������^��n�ut�L �W��+ ���hO��^�w�\i� ��:9>3�=��So�2v���U1z��.�^�ߋěN���,���� �f��V�    IEND�B`�           [remap]

importer="texture"
type="StreamTexture"
path="res://.import/icon.png-487276ed1e3a0c39cad0279d744ee560.stex"
metadata={
"vram_texture": false
}

[deps]

source_file="res://icon.png"
dest_files=[ "res://.import/icon.png-487276ed1e3a0c39cad0279d744ee560.stex" ]

[params]

compress/mode=0
compress/lossy_quality=0.7
compress/hdr_mode=0
compress/bptc_ldr=0
compress/normal_map=0
flags/repeat=0
flags/filter=true
flags/mipmaps=false
flags/anisotropic=false
flags/srgb=2
process/fix_alpha_border=true
process/premult_alpha=false
process/HDR_as_SRGB=false
process/invert_color=false
stream=false
size_limit=0
detect_3d=true
svg/scale=1.0
[remap]

path="res://Scenes/Main.gdc"
          [remap]

path="res://Scripts/Dict.gdc"
         [remap]

path="res://Scripts/Dictionnaire.gdc"
 [remap]

path="res://Scripts/VBoxContainer.gdc"
[remap]

path="res://Scripts/WordButton.gdc"
   [remap]

path="res://Scripts/WordGenerator.gdc"
[remap]

path="res://Scripts/WordLinker.gdc"
   [remap]

path="res://Scripts/WordSelector.gdc"
 �PNG

   IHDR   @   @   �iq�   sRGB ���  �IDATx��ytTU��?�ի%���@ȞY1JZ �iA�i�[P��e��c;�.`Ow+4�>�(}z�EF�Dm�:�h��IHHB�BR!{%�Zߛ?��	U�T�
���:��]~�������-�	Ì�{q*�h$e-
�)��'�d�b(��.�B�6��J�ĩ=;���Cv�j��E~Z��+��CQ�AA�����;�.�	�^P	���ARkUjQ�b�,#;�8�6��P~,� �0�h%*QzE� �"��T��
�=1p:lX�Pd�Y���(:g����kZx ��A���띊3G�Di� !�6����A҆ @�$JkD�$��/�nYE��< Q���<]V�5O!���>2<��f��8�I��8��f:a�|+�/�l9�DEp�-�t]9)C�o��M~�k��tw�r������w��|r�Ξ�	�S�)^� ��c�eg$�vE17ϟ�(�|���Ѧ*����
����^���uD�̴D����h�����R��O�bv�Y����j^�SN֝
������PP���������Y>����&�P��.3+�$��ݷ�����{n����_5c�99�fbסF&�k�mv���bN�T���F���A�9�
(.�'*"��[��c�{ԛmNު8���3�~V� az
�沵�f�sD��&+[���ke3o>r��������T�]����* ���f�~nX�Ȉ���w+�G���F�,U�� D�Դ0赍�!�B�q�c�(
ܱ��f�yT�:��1�� +����C|��-�T��D�M��\|�K�j��<yJ, ����n��1.FZ�d$I0݀8]��Jn_� ���j~����ցV���������1@M�)`F�BM����^x�>
����`��I�˿��wΛ	����W[�����v��E�����u��~��{R�(����3���������y����C��!��nHe�T�Z�����K�P`ǁF´�nH啝���=>id,�>�GW-糓F������m<P8�{o[D����w�Q��=N}�!+�����-�<{[���������w�u�L�����4�����Uc�s��F�륟��c�g�u�s��N��lu���}ן($D��ת8m�Q�V	l�;��(��ڌ���k�
s\��JDIͦOzp��مh����T���IDI���W�Iǧ�X���g��O��a�\:���>����g���%|����i)	�v��]u.�^�:Gk��i)	>��T@k{'	=�������@a�$zZ�;}�󩀒��T�6�Xq&1aWO�,&L�cřT�4P���g[�
p�2��~;� ��Ҭ�29�xri� ��?��)��_��@s[��^�ܴhnɝ4&'
��NanZ4��^Js[ǘ��2���x?Oܷ�$��3�$r����Q��1@�����~��Y�Qܑ�Hjl(}�v�4vSr�iT�1���f������(���A�ᥕ�$� X,�3'�0s����×ƺk~2~'�[�ё�&F�8{2O�y�n�-`^/FPB�?.�N�AO]]�� �n]β[�SR�kN%;>�k��5������]8������=p����Ցh������`}�
�J�8-��ʺ����� �fl˫[8�?E9q�2&������p��<�r�8x� [^݂��2�X��z�V+7N����V@j�A����hl��/+/'5�3�?;9
�(�Ef'Gyҍ���̣�h4RSS� ����������j�Z��jI��x��dE-y�a�X�/�����:��� +k�� �"˖/���+`��],[��UVV4u��P �˻�AA`��)*ZB\\��9lܸ�]{N��礑]6�Hnnqqq-a��Qxy�7�`=8A�Sm&�Q�����u�0hsPz����yJt�[�>�/ޫ�il�����.��ǳ���9��
_
��<s���wT�S������;F����-{k�����T�Z^���z�!t�۰؝^�^*���؝c
���;��7]h^
��PA��+@��gA*+�K��ˌ�)S�1��(Ե��ǯ�h����õ�M�`��p�cC�T")�z�j�w��V��@��D��N�^M\����m�zY��C�Ҙ�I����N�Ϭ��{�9�)����o���C���h�����ʆ.��׏(�ҫ���@�Tf%yZt���wg�4s�]f�q뗣�ǆi�l�⵲3t��I���O��v;Z�g��l��l��kAJѩU^wj�(��������{���)�9�T���KrE�V!�D���aw���x[�I��tZ�0Y �%E�͹���n�G�P�"5FӨ��M�K�!>R���$�.x����h=gϝ�K&@-F��=}�=�����5���s �CFwa���8��u?_����D#���x:R!5&��_�]���*�O��;�)Ȉ�@�g�����ou�Q�v���J�G�6�P�������7��-���	պ^#�C�S��[]3��1���IY��.Ȉ!6\K�:��?9�Ev��S]�l;��?/� ��5�p�X��f�1�;5�S�ye��Ƅ���,Da�>�� O.�AJL(���pL�C5ij޿hBƾ���ڎ�)s��9$D�p���I��e�,ə�+;?�t��v�p�-��&����	V���x���yuo-G&8->�xt�t������Rv��Y�4ZnT�4P]�HA�4�a�T�ǅ1`u\�,���hZ����S������o翿���{�릨ZRq��Y��fat�[����[z9��4�U�V��Anb$Kg������]������8�M0(WeU�H�\n_��¹�C�F�F�}����8d�N��.��]���u�,%Z�F-���E�'����q�L�\������=H�W'�L{�BP0Z���Y�̞���DE��I�N7���c��S���7�Xm�/`�	�+`����X_��KI��^��F\�aD�����~�+M����ㅤ��	SY��/�.�`���:�9Q�c �38K�j�0Y�D�8����W;ܲ�pTt��6P,� Nǵ��Æ�:(���&�N�/ X��i%�?�_P	�n�F�.^�G�E���鬫>?���"@v�2���A~�aԹ_[P, n��N������_rƢ��    IEND�B`�       ECFG      application/config/name      	   Kracnodar      application/run/main_scene          res://Scenes/Main.tscn     application/config/icon         res://icon.png     autoload/Dict          *res://Scripts/Dict.gd  )   physics/common/enable_pause_aware_picking         )   rendering/environment/default_environment          res://default_env.tres               